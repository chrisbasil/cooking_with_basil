// Supabase Edge Function: parse-recipe
//
// Single source of truth for recipe import parsing. Handles URL, raw HTML,
// plain text, and PDF page images. Uses a cheap JSON-LD fast path for modern
// recipe sites; everything else routes through Claude Sonnet 4.6 with
// tool-use for guaranteed-shape structured output.
//
// Deploy: supabase functions deploy parse-recipe
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ─── Types ──────────────────────────────────────────────────────────────
interface Taxonomy {
  cuisines: string[];
  difficulties: string[];
  proteins: string[];
  categories: string[];
  tags: string[];
}

interface Recipe {
  title?: string;
  source?: string;
  summary?: string;
  ingredients?: string;
  instructions?: string;
  notes?: string;
  shopping_tags?: string;
  prep_time?: string;
  cook_time?: string;
  total_time?: string;
  servings?: string;
  yield?: string;
  difficulty?: string;
  cuisine?: string;
  protein?: string;
  tags?: string[];
}

type ParseMethod = "json-ld" | "claude-text" | "claude-vision";

interface ParseResponse {
  recipe: Recipe;
  parse_method: ParseMethod;
  warnings: string[];
  usage: {
    input_tokens: number;
    output_tokens: number;
    cache_read_input_tokens: number;
    cache_creation_input_tokens: number;
  } | null;
}

// ─── CORS ───────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

function errorResponse(status: number, error: string, detail?: unknown) {
  return new Response(JSON.stringify({ error, detail }), {
    status,
    headers: jsonHeaders,
  });
}

// ─── URL fetch (absorbs fetch-recipe) ───────────────────────────────────
async function fetchUrl(url: string): Promise<string> {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error("Invalid URL");
  }
  if (!["http:", "https:"].includes(parsed.protocol)) {
    throw new Error("Only http(s) URLs allowed");
  }
  const response = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; CookingWithBasil/1.0)",
      Accept: "text/html,application/xhtml+xml",
    },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`Upstream HTTP ${response.status}`);
  const html = await response.text();
  return html.length > 500_000 ? html.slice(0, 500_000) : html;
}

// ─── JSON-LD fast path ──────────────────────────────────────────────────
function isoDuration(iso: unknown): string {
  if (typeof iso !== "string") return "";
  const m = iso.match(/^PT(?:(\d+)H)?(?:(\d+)M)?/);
  if (!m) return iso;
  const parts: string[] = [];
  if (m[1]) parts.push(`${m[1]} hr`);
  if (m[2]) parts.push(`${m[2]} min`);
  return parts.join(" ") || iso;
}

function findRecipeNode(node: unknown): Record<string, unknown> | null {
  if (!node) return null;
  if (Array.isArray(node)) {
    for (const item of node) {
      const hit = findRecipeNode(item);
      if (hit) return hit;
    }
    return null;
  }
  if (typeof node !== "object") return null;
  const obj = node as Record<string, unknown>;
  const type = obj["@type"];
  const isRecipe = type === "Recipe" ||
    (Array.isArray(type) && type.includes("Recipe"));
  if (isRecipe) return obj;
  if (Array.isArray(obj["@graph"])) {
    return findRecipeNode(obj["@graph"]);
  }
  return null;
}

function extractJsonLd(html: string): Recipe | null {
  const matches = html.match(
    /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
  );
  if (!matches) return null;

  for (const block of matches) {
    const json = block.replace(/<\/?script[^>]*>/gi, "").trim();
    let data: unknown;
    try {
      data = JSON.parse(json);
    } catch {
      // Some sites emit concatenated JSON-LD blocks — try array wrap
      try {
        data = JSON.parse(`[${json}]`);
      } catch {
        continue;
      }
    }
    const node = findRecipeNode(data);
    if (!node) continue;

    const recipe: Recipe = {};
    if (typeof node.name === "string") recipe.title = node.name.trim();
    if (typeof node.description === "string") {
      recipe.summary = node.description.trim();
    }
    const ing = node.recipeIngredient;
    if (Array.isArray(ing)) {
      recipe.ingredients = ing.map(String).join("\n");
    }
    const inst = node.recipeInstructions;
    if (typeof inst === "string") {
      recipe.instructions = inst;
    } else if (Array.isArray(inst)) {
      recipe.instructions = inst
        .map((step, i) => {
          if (typeof step === "string") return `${i + 1}. ${step}`;
          const s = step as Record<string, unknown>;
          const text = typeof s.text === "string"
            ? s.text
            : typeof s.name === "string"
            ? s.name
            : "";
          return `${i + 1}. ${text}`;
        })
        .join("\n");
    }
    if (node.prepTime) recipe.prep_time = isoDuration(node.prepTime);
    if (node.cookTime) recipe.cook_time = isoDuration(node.cookTime);
    if (node.totalTime) recipe.total_time = isoDuration(node.totalTime);
    if (node.recipeYield) {
      const y = Array.isArray(node.recipeYield)
        ? node.recipeYield[0]
        : node.recipeYield;
      recipe.servings = String(y);
    }
    if (Array.isArray(node.recipeCategory)) {
      recipe.tags = node.recipeCategory.map(String);
    } else if (typeof node.recipeCategory === "string") {
      recipe.tags = [node.recipeCategory];
    }
    if (Array.isArray(node.recipeCuisine)) {
      recipe.cuisine = String(node.recipeCuisine[0] ?? "").toLowerCase();
    } else if (typeof node.recipeCuisine === "string") {
      recipe.cuisine = node.recipeCuisine.toLowerCase();
    }

    // Must have title + ingredients + instructions to be "usable"
    if (recipe.title && recipe.ingredients && recipe.instructions) {
      return recipe;
    }
  }
  return null;
}

// ─── HTML → text stripper (feeds Claude when JSON-LD misses) ────────────
function htmlToText(html: string): string {
  // Drop scripts/styles entirely, then replace tags with newlines so we
  // preserve some structure for the model.
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<\/?(?:p|div|li|h[1-6]|br|tr|td|section|article)[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// ─── Claude prompt + tool schema ────────────────────────────────────────
function buildSystemPrompt(tx: Taxonomy): string {
  return `You are a precise recipe extractor for a home meal-planning app.

Given a recipe source (web page text, pasted text, or PDF page images), extract the recipe into the exact fields required by the emit_recipe tool. Always call the tool; never reply with plain text.

Rules:
- Title: the dish name only (no site name, no SEO suffix, no "Recipe by X").
- Summary: 1–2 sentence blurb. Leave empty if none is present.
- Ingredients: one item per line, exactly as written (quantities + item). No bullet glyphs.
- Instructions: numbered steps ("1. ...", "2. ...") one per line. Merge narrative prose into clean steps.
- Times (prep_time, cook_time, total_time): normalize to "X min" or "X hr Y min". If the source gives "1 hour", output "1 hr". Leave empty if not given.
- Servings: the numeric serving count if stated (e.g. "4", "6-8"). Leave empty if absent.
- Yield: only when the source uses a yield measurement instead of servings (e.g. "12 cookies", "1 loaf").
- Difficulty: one of [${tx.difficulties.join(", ")}]. Omit if not obvious.
- Cuisine: one of [${tx.cuisines.join(", ")}]. Omit if unclear. Do NOT invent cuisines.
- Protein: one of [${tx.proteins.join(", ")}]. Infer from ingredients:
    * vegetarian = no meat or fish
    * fish = seafood/fish only
    * meat = beef/pork/poultry/lamb/game
    * adaptable = source explicitly notes a meat/vegetarian swap
- Tags: 0–6 tags from this vocab only — [${tx.tags.join(", ")}]. Do not invent tags.
- Notes: author tips, serving suggestions, storage advice — things that are not steps.
- Shopping_tags: short comma-separated hints for grocery planning (e.g. "pantry, produce, dairy"). Leave empty if unknown.
- Warnings: free-text list. Populate whenever you had to guess, skip, or infer a field. One concern per entry.

Never fabricate ingredients or steps. If a field is missing, leave it empty and add a warning.`;
}

const emitRecipeTool = (tx: Taxonomy) => {
  // Guard against empty enum arrays (tool-use requires a non-empty enum when
  // the keyword is present). When a vocab is empty, fall back to free-form
  // strings; the outer validateAgainstTaxonomy will still clear unknown values.
  const enumField = (values: string[]) =>
    values.length
      ? { type: "string", enum: ["", ...values] }
      : { type: "string" };
  const arrayEnumField = (values: string[]) =>
    values.length
      ? { type: "array", items: { type: "string", enum: values } }
      : { type: "array", items: { type: "string" } };

  return {
    name: "emit_recipe",
    description:
      "Emit the structured recipe. Always call exactly once per request.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        summary: { type: "string" },
        ingredients: { type: "string" },
        instructions: { type: "string" },
        notes: { type: "string" },
        shopping_tags: { type: "string" },
        prep_time: { type: "string" },
        cook_time: { type: "string" },
        total_time: { type: "string" },
        servings: { type: "string" },
        yield: { type: "string" },
        difficulty: enumField(tx.difficulties),
        cuisine: enumField(tx.cuisines),
        protein: enumField(tx.proteins),
        tags: arrayEnumField(tx.tags),
        warnings: { type: "array", items: { type: "string" } },
      },
      required: ["title", "ingredients", "instructions", "warnings"],
    },
  };
};

// ─── Claude call ────────────────────────────────────────────────────────
interface ClaudeResult {
  recipe: Recipe;
  warnings: string[];
  usage: ParseResponse["usage"];
}

async function callClaude(
  apiKey: string,
  tx: Taxonomy,
  userContent: unknown[],
): Promise<ClaudeResult> {
  const body = {
    model: "claude-sonnet-4-6",
    max_tokens: 4096,
    system: [
      {
        type: "text",
        text: buildSystemPrompt(tx),
        cache_control: { type: "ephemeral" },
      },
    ],
    tools: [emitRecipeTool(tx)],
    tool_choice: { type: "tool", name: "emit_recipe" },
    messages: [{ role: "user", content: userContent }],
  };

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(60_000),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Anthropic API ${res.status}: ${text.slice(0, 500)}`);
  }

  const data = await res.json() as {
    content: Array<{ type: string; name?: string; input?: unknown }>;
    usage?: {
      input_tokens: number;
      output_tokens: number;
      cache_read_input_tokens?: number;
      cache_creation_input_tokens?: number;
    };
  };

  const toolBlock = data.content.find(
    (b) => b.type === "tool_use" && b.name === "emit_recipe",
  );
  if (!toolBlock || !toolBlock.input) {
    throw new Error("Claude did not return an emit_recipe tool call");
  }

  const input = toolBlock.input as Record<string, unknown>;
  const warnings = Array.isArray(input.warnings)
    ? (input.warnings as string[])
    : [];

  const recipe: Recipe = {
    title: (input.title as string) || "",
    summary: (input.summary as string) || "",
    ingredients: (input.ingredients as string) || "",
    instructions: (input.instructions as string) || "",
    notes: (input.notes as string) || "",
    shopping_tags: (input.shopping_tags as string) || "",
    prep_time: (input.prep_time as string) || "",
    cook_time: (input.cook_time as string) || "",
    total_time: (input.total_time as string) || "",
    servings: (input.servings as string) || "",
    yield: (input.yield as string) || "",
    difficulty: (input.difficulty as string) || "",
    cuisine: (input.cuisine as string) || "",
    protein: (input.protein as string) || "",
    tags: Array.isArray(input.tags) ? (input.tags as string[]) : [],
  };

  return {
    recipe,
    warnings,
    usage: {
      input_tokens: data.usage?.input_tokens ?? 0,
      output_tokens: data.usage?.output_tokens ?? 0,
      cache_read_input_tokens: data.usage?.cache_read_input_tokens ?? 0,
      cache_creation_input_tokens: data.usage?.cache_creation_input_tokens ?? 0,
    },
  };
}

// ─── Validation against taxonomy ────────────────────────────────────────
function validateAgainstTaxonomy(recipe: Recipe, tx: Taxonomy): string[] {
  const warnings: string[] = [];
  const inSet = (v: string | undefined, set: string[]) =>
    !v || set.includes(v);

  if (!inSet(recipe.cuisine, tx.cuisines)) {
    warnings.push(`Unknown cuisine "${recipe.cuisine}" — cleared.`);
    recipe.cuisine = "";
  }
  if (!inSet(recipe.difficulty, tx.difficulties)) {
    warnings.push(`Unknown difficulty "${recipe.difficulty}" — cleared.`);
    recipe.difficulty = "";
  }
  if (!inSet(recipe.protein, tx.proteins)) {
    warnings.push(`Unknown protein "${recipe.protein}" — cleared.`);
    recipe.protein = "";
  }
  if (Array.isArray(recipe.tags)) {
    const kept = recipe.tags.filter((t) => tx.tags.includes(t));
    if (kept.length !== recipe.tags.length) {
      warnings.push(
        `Dropped ${recipe.tags.length - kept.length} tag(s) not in vocab.`,
      );
      recipe.tags = kept;
    }
  }
  return warnings;
}

// ─── Request handler ────────────────────────────────────────────────────
interface ParseRequest {
  kind: "url" | "html" | "text" | "images";
  content: string | string[];
  source?: string;
  taxonomy: Taxonomy;
}

async function handle(req: ParseRequest): Promise<ParseResponse> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey && req.kind !== "url" && req.kind !== "html") {
    // url/html can still succeed via JSON-LD; text/images always need Claude.
    throw new Error(
      "ANTHROPIC_API_KEY is not set on the edge function. Run: supabase secrets set ANTHROPIC_API_KEY=...",
    );
  }

  const tx = req.taxonomy;
  if (!tx || !Array.isArray(tx.cuisines)) {
    throw new Error("Missing taxonomy in request body");
  }

  // URL → fetch HTML server-side, then fall through to html path
  let html: string | null = null;
  if (req.kind === "url") {
    if (typeof req.content !== "string") {
      throw new Error("content must be a URL string for kind=url");
    }
    html = await fetchUrl(req.content);
  } else if (req.kind === "html") {
    if (typeof req.content !== "string") {
      throw new Error("content must be an HTML string for kind=html");
    }
    html = req.content;
  }

  // HTML → JSON-LD fast path
  if (html !== null) {
    const fromLd = extractJsonLd(html);
    if (fromLd) {
      if (req.source && !fromLd.source) fromLd.source = req.source;
      else if (req.kind === "url" && !fromLd.source) {
        fromLd.source = req.content as string;
      }
      const warnings = validateAgainstTaxonomy(fromLd, tx);
      return {
        recipe: fromLd,
        parse_method: "json-ld",
        warnings,
        usage: null,
      };
    }
  }

  if (!apiKey) {
    throw new Error(
      "Could not extract recipe via JSON-LD and ANTHROPIC_API_KEY is not set. Configure the secret to enable Claude-based parsing.",
    );
  }

  // Claude paths
  let userContent: unknown[];
  let parseMethod: ParseMethod;

  if (req.kind === "images") {
    if (!Array.isArray(req.content)) {
      throw new Error("content must be an array of base64 strings for kind=images");
    }
    if (req.content.length === 0) throw new Error("No images provided");
    if (req.content.length > 10) {
      throw new Error("Max 10 images per request");
    }
    userContent = [
      ...req.content.map((b64) => ({
        type: "image",
        source: {
          type: "base64",
          media_type: "image/png",
          data: b64,
        } as const,
      })),
      {
        type: "text",
        text:
          "Extract the recipe from these page images. Follow the emit_recipe tool schema exactly.",
      },
    ];
    parseMethod = "claude-vision";
  } else {
    const text = html !== null
      ? htmlToText(html)
      : typeof req.content === "string"
      ? req.content
      : "";
    if (!text.trim()) throw new Error("Empty content");
    userContent = [
      {
        type: "text",
        text: `Extract the recipe from the text below. Follow the emit_recipe tool schema exactly.\n\n---\n\n${
          text.slice(0, 80_000)
        }`,
      },
    ];
    parseMethod = "claude-text";
  }

  const result = await callClaude(apiKey, tx, userContent);
  const recipe = result.recipe;
  if (req.source && !recipe.source) recipe.source = req.source;
  else if (req.kind === "url" && !recipe.source) {
    recipe.source = req.content as string;
  }

  const txWarnings = validateAgainstTaxonomy(recipe, tx);

  return {
    recipe,
    parse_method: parseMethod,
    warnings: [...result.warnings, ...txWarnings],
    usage: result.usage,
  };
}

// ─── Server ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  let body: ParseRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "Invalid JSON body");
  }

  try {
    const result = await handle(body);
    return new Response(JSON.stringify(result), { headers: jsonHeaders });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    const status = /Invalid URL|Only http|Missing taxonomy|Empty|Max 10|content must be/
        .test(msg)
      ? 400
      : /ANTHROPIC_API_KEY/.test(msg)
      ? 500
      : /Upstream HTTP/.test(msg)
      ? 502
      : 500;
    return errorResponse(status, msg);
  }
});
