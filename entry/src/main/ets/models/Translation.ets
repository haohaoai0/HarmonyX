// Translation domain model.
// The provider presets mirror the catalogue the reference client ships in
// its own ai_model_config resource: an OpenAI-compatible endpoint per vendor
// plus Anthropic's native Messages API. Users supply their own key, so the
// app never proxies translation through a Harmony X server.
import { SUPPORTED_APP_LANGUAGE_TAGS } from '../services/LanguageStore';

export const TRANSLATION_PROTOCOL_OPENAI: string = 'openai';
export const TRANSLATION_PROTOCOL_ANTHROPIC: string = 'anthropic';

// The API mode keeps the existing bring-your-own-key workflow. Web mode uses
// the translation website's public endpoint instead, so it needs no model or
// key configuration. It is deliberately a separate mode rather than a fake
// provider: no credential must ever be sent to the web translation service.
export const TRANSLATION_MODE_API: string = 'api';
export const TRANSLATION_MODE_WEB: string = 'web';
// Uses the signed-in X account's post translation, without an xAI API key.
export const TRANSLATION_MODE_X: string = 'x_grok';

export const TARGET_LANGUAGE_ZH: string = 'zh-CN';
export const TARGET_LANGUAGE_EN: string = 'en';
export const TARGET_LANGUAGE_JA: string = 'ja';
export const TARGET_LANGUAGE_APP: string = 'app';
export const SOURCE_LANGUAGE_AUTO: string = 'auto';
export const DEFAULT_TARGET_LANGUAGE: string = TARGET_LANGUAGE_APP;
export const DEFAULT_SOURCE_LANGUAGE: string = SOURCE_LANGUAGE_AUTO;

export interface TranslationProvider {
  id: string;
  name: string;
  baseUrl: string;
  protocol: string;
  models: string[];
  // Extra header some vendors require on every request (Anthropic version).
  extraHeaderName: string;
  extraHeaderValue: string;
  // True when the vendor accepts OpenAI's reasoning_effort control.
  supportsReasoningEffort: boolean;
  // Azure endpoints are per-customer, so the user must fill the base URL.
  requiresCustomBaseUrl: boolean;
}

export const TRANSLATION_PROVIDERS: TranslationProvider[] = [
  {
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['gpt-5.5', 'gpt-5.5-pro', 'gpt-5.4', 'gpt-5.4-mini', 'gpt-5.2', 'gpt-5-mini'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: true,
    requiresCustomBaseUrl: false
  },
  {
    id: 'azure_openai',
    name: 'Azure OpenAI',
    baseUrl: '',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['gpt-5.5', 'gpt-5.4', 'gpt-5.2', 'gpt-5-mini'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: true,
    requiresCustomBaseUrl: true
  },
  {
    id: 'claude',
    name: 'Claude',
    baseUrl: 'https://api.anthropic.com/v1',
    protocol: TRANSLATION_PROTOCOL_ANTHROPIC,
    models: ['claude-sonnet-4-6', 'claude-opus-4-8', 'claude-opus-4-7', 'claude-haiku-4-5-20251001'],
    extraHeaderName: 'anthropic-version',
    extraHeaderValue: '2023-06-01',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'gemini',
    name: 'Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['gemini-3.5-flash', 'gemini-3.1-pro-preview', 'gemini-2.5-pro', 'gemini-2.5-flash'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: true,
    requiresCustomBaseUrl: false
  },
  {
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['deepseek-v4-pro', 'deepseek-v4-flash'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'qwen',
    name: '通义千问',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['qwen-mt-plus', 'qwen-mt-flash', 'qwen3.7-max', 'qwen3.6-plus', 'qwen-plus'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'kimi',
    name: 'Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['kimi-k2.6', 'kimi-k2.5'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'zhi_pu',
    name: '智谱 AI',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['glm-5', 'glm-4.7', 'glm-4.7-flash', 'glm-4.6'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'dou_bao',
    name: '豆包',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['doubao-seed-2-0-pro-260215', 'doubao-seed-2-0-lite-260215', 'doubao-seed-2-0-mini-260215'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: true,
    requiresCustomBaseUrl: false
  },
  {
    id: 'hun_yuan',
    name: '腾讯混元',
    baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['hunyuan-turbos-latest', 'hunyuan-t1-latest', 'hunyuan-standard', 'hunyuan-lite'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  },
  {
    id: 'silicon_flow',
    name: 'SiliconFlow',
    baseUrl: 'https://api.siliconflow.cn/v1',
    protocol: TRANSLATION_PROTOCOL_OPENAI,
    models: ['Qwen/Qwen3-8B', 'THUDM/GLM-Z1-9B-0414', 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B'],
    extraHeaderName: '',
    extraHeaderValue: '',
    supportsReasoningEffort: false,
    requiresCustomBaseUrl: false
  }
];

export function findTranslationProvider(id: string): TranslationProvider | undefined {
  for (let i: number = 0; i < TRANSLATION_PROVIDERS.length; i++) {
    if (TRANSLATION_PROVIDERS[i].id === id) {
      return TRANSLATION_PROVIDERS[i];
    }
  }
  return undefined;
}

export function isValidTargetLanguage(value: string): boolean {
  return value === TARGET_LANGUAGE_APP || isSupportedTranslationLanguage(value);
}

export function isValidSourceLanguage(value: string): boolean {
  return value === SOURCE_LANGUAGE_AUTO || isSupportedTranslationLanguage(value);
}

function isSupportedTranslationLanguage(value: string): boolean {
  const language: string = normalizeTranslationLanguage(value);
  if (language.length === 0) { return false; }
  for (let i: number = 0; i < SUPPORTED_APP_LANGUAGE_TAGS.length; i++) {
    if (normalizeTranslationLanguage(SUPPORTED_APP_LANGUAGE_TAGS[i]) === language) { return true; }
  }
  return false;
}

// Share the app's language inventory. Requests use canonical language codes,
// while regional variants and legacy Indonesian codes match the same setting.
export function normalizeTranslationLanguage(value: string): string {
  const language: string = value.trim().toLowerCase().replace(/_/g, '-');
  if (language === 'zh' || language.startsWith('zh-')) {
    if (language.indexOf('hant') >= 0 || /^zh-(tw|hk|mo)(-|$)/.test(language)) {
      return 'zh-TW';
    }
    return TARGET_LANGUAGE_ZH;
  }
  const base: string = language.split('-')[0];
  if (base === 'in') { return 'id'; }
  // Posts can be in languages outside the app's selectable catalog. Keep
  // their code so an unrelated exclusion does not suppress their translation.
  if (base === 'und' || base === 'zxx' || base === 'mul') { return ''; }
  return /^[a-z]{2,3}$/.test(base) ? base : '';
}

export function sameTranslationLanguage(left: string, right: string): boolean {
  const first: string = normalizeTranslationLanguage(left);
  const second: string = normalizeTranslationLanguage(right);
  return first.length > 0 && second.length > 0 && first.split('-')[0] === second.split('-')[0];
}

export function translationLanguageName(value: string): string {
  switch (normalizeTranslationLanguage(value)) {
    case 'zh-CN': return 'Simplified Chinese';
    case 'zh-TW': return 'Traditional Chinese';
    case 'en': return 'English';
    case 'ru': return 'Russian';
    case 'uk': return 'Ukrainian';
    case 'fa': return 'Persian';
    case 'ar': return 'Arabic';
    case 'id': return 'Indonesian';
    case 'ms': return 'Malay';
    case 'tr': return 'Turkish';
    case 'vi': return 'Vietnamese';
    case 'th': return 'Thai';
    case 'ja': return 'Japanese';
    case 'ko': return 'Korean';
    case 'de': return 'German';
    case 'fr': return 'French';
    case 'es': return 'Spanish';
    case 'pt': return 'Portuguese';
    case 'it': return 'Italian';
    case 'hi': return 'Hindi';
    default: return value;
  }
}

export function normalizeExcludedTranslationLanguages(value: string): string {
  const candidates: string[] = value.split(',');
  let normalized: string = '';
  for (let i: number = 0; i < candidates.length; i++) {
    const language: string = normalizeTranslationLanguage(candidates[i]);
    if (!isSupportedTranslationLanguage(language) || (',' + normalized + ',').indexOf(',' + language + ',') >= 0) {
      continue;
    }
    normalized += normalized.length === 0 ? language : ',' + language;
  }
  return normalized;
}

export function isValidTranslationMode(value: string): boolean {
  return value === TRANSLATION_MODE_API || value === TRANSLATION_MODE_WEB || value === TRANSLATION_MODE_X;
}
