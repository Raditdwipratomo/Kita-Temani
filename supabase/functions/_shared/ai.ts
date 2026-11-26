// supabase/functions/_shared/ai.ts
// Unified OpenRouter client: prioritizes Qwen (when account has credits) and
// automatically falls back across live OpenRouter free models on 402/429/404/5xx.

export interface ChatCompletionOptions {
  messages: unknown[];
  vision?: boolean;
  temperature?: number;
  maxTokens?: number;
  jsonMode?: boolean;
}

export type ChatCompletionResult =
  | { ok: true; content: string; model: string }
  | { ok: false; status: number; message: string; triedModels: string[] };

const DEFAULT_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';

// Verified live OpenRouter slugs: Qwen primary (used automatically once credits exist),
// followed by fastest healthy zero-cost OpenRouter models & smart free router.
const DEFAULT_TEXT_MODELS = [
  'qwen/qwen3.7-flash',
  'baidu/ernie-5.5-flash-preview:free',
  'openrouter/free',
  'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
  'particle-ai/particle-1:free',
  'nvidia/nemotron-3.5-super-vl:free',
  'inclusionai/ling-3.2-flash:free',
  'nvidia/nemotron-3.5-lightning:free',
  'nvidia/nemotron-3-ultra-550b-a55b:free',
  'google/gemma-4-26b-a4b-it:free',
  'google/gemma-4-31b-it:free',
  'liquid/lfm-3-1.7b:free',
];

const DEFAULT_VISION_MODELS = [
  'qwen/qwen3.7-flash',
  'openrouter/free',
  'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
  'nvidia/nemotron-3.5-super-vl:free',
  'inclusionai/ling-3.2-flash:free',
  'particle-ai/particle-1:free',
  'google/gemma-4-26b-a4b-it:free',
  'google/gemma-4-31b-it:free',
];

function resolveApiKey(): string {
  return (Deno.env.get('OPENROUTER_API_KEY') ?? Deno.env.get('AI_API_KEY') ?? '').trim();
}

function resolveEndpoint(): string {
  const custom = (
    Deno.env.get('OPENROUTER_BASE_URL') ??
    Deno.env.get('AI_BASE_URL') ??
    ''
  ).trim();
  if (!custom) return DEFAULT_ENDPOINT;
  return custom.endsWith('/chat/completions')
    ? custom
    : `${custom.replace(/\/+$/, '')}/chat/completions`;
}

function resolveModelCandidates(vision: boolean): string[] {
  const configured = vision
    ? (Deno.env.get('OPENROUTER_VISION_MODEL') ?? Deno.env.get('AI_VISION_MODEL') ?? '').trim()
    : (Deno.env.get('OPENROUTER_MODEL') ?? Deno.env.get('AI_MODEL') ?? '').trim();

  const defaults = vision ? DEFAULT_VISION_MODELS : DEFAULT_TEXT_MODELS;
  if (!configured) return defaults;
  return [configured, ...defaults.filter((m) => m !== configured)];
}

export function stripReasoningTags(raw: string): string {
  return raw
    .replace(/<think>[\s\S]*?<\/think>\s*/gi, '')
    .replace(/<reasoning>[\s\S]*?<\/reasoning>\s*/gi, '')
    .trim();
}

function extractMessageText(data: unknown): string {
  const choice = (data as { choices?: Array<{ message?: { content?: unknown } }> })
    ?.choices?.[0];
  const content = choice?.message?.content;
  if (typeof content === 'string') {
    return stripReasoningTags(content);
  }
  if (Array.isArray(content)) {
    const joined = content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part === 'object' && 'text' in part) {
          return String((part as { text?: unknown }).text ?? '');
        }
        return '';
      })
      .join('\n');
    return stripReasoningTags(joined);
  }
  return '';
}

function formatOpenRouterError(status: number, rawBody: string, model: string): string {
  let detail = '';
  try {
    const parsed = JSON.parse(rawBody);
    detail = parsed?.error?.message ?? parsed?.message ?? '';
  } catch (_) {
    detail = rawBody.slice(0, 180);
  }

  if (status === 401) {
    return 'OPENROUTER_API_KEY tidak valid atau sudah dicabut. Periksa secret di Supabase.';
  }
  if (status === 402) {
    return `Saldo OpenRouter tidak mencukupi untuk model ${model} (${detail || '402 Payment Required'}).`;
  }
  if (status === 404) {
    return `Model ${model} tidak tersedia atau diblokir pengaturan privasi OpenRouter (${detail || '404'}).`;
  }
  if (status === 429) {
    return `Batas request OpenRouter sementara tercapai untuk ${model}. Coba beberapa saat lagi.`;
  }
  return `OpenRouter error (${status}) pada ${model}: ${detail || 'gagal menghubungi model AI.'}`;
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs = 15000,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export async function callQwenChatCompletion(
  options: ChatCompletionOptions,
): Promise<ChatCompletionResult> {
  const apiKey = resolveApiKey();
  if (!apiKey) {
    return {
      ok: false,
      status: 503,
      message: 'OPENROUTER_API_KEY belum diatur di Supabase Edge Function Secrets.',
      triedModels: [],
    };
  }

  const endpoint = resolveEndpoint();
  const candidates = resolveModelCandidates(Boolean(options.vision));
  const referer = Deno.env.get('OPENROUTER_SITE_URL') ?? 'https://kitatemani.id';
  const title = Deno.env.get('OPENROUTER_APP_NAME') ?? 'KitaTemani';

  let lastStatus = 502;
  let lastMessage = 'Gagal terhubung ke layanan OpenRouter.';
  const triedModels: string[] = [];

  for (const model of candidates) {
    triedModels.push(model);
    try {
      const payload: Record<string, unknown> = {
        model,
        temperature: options.temperature ?? 0.5,
        max_tokens: Math.max(options.maxTokens ?? 900, 900),
        messages: options.messages,
      };
      if (options.jsonMode) {
        payload.response_format = { type: 'json_object' };
      }

      const headers = {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
        'HTTP-Referer': referer,
        'X-Title': title,
      };

      let res = await fetchWithTimeout(endpoint, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });

      if (res.status === 400 && options.jsonMode) {
        delete payload.response_format;
        res = await fetchWithTimeout(endpoint, {
          method: 'POST',
          headers,
          body: JSON.stringify(payload),
        });
      }

      if (res.ok) {
        const data = await res.json();
        const clean = extractMessageText(data);
        if (clean) {
          const actualModel =
            typeof data?.model === 'string' && data.model.trim()
              ? data.model.trim()
              : model;
          return { ok: true, content: clean, model: actualModel };
        }
        lastStatus = 502;
        lastMessage = `Model ${model} mengembalikan respons kosong.`;
        continue;
      }

      const errText = await res.text();
      lastStatus = res.status;
      lastMessage = formatOpenRouterError(res.status, errText, model);

      // Invalid API key: fail immediately (no point retrying other models).
      if (res.status === 401) {
        return { ok: false, status: lastStatus, message: lastMessage, triedModels };
      }

      // 402 (paid model on $0 account), 404 (privacy/unavailable), 429 (rate limit),
      // 400 (model-specific incompatibility), or 5xx: try next candidate automatically!
    } catch (err) {
      lastStatus = 502;
      lastMessage = `Koneksi ke OpenRouter gagal (${model}): ${err instanceof Error ? err.message : String(err)}`;
    }
  }

  return { ok: false, status: lastStatus, message: lastMessage, triedModels };
}
