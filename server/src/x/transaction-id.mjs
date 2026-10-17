// X-Client-Transaction-Id provider chain.
//
// X's edge expects this header on authenticated calls. The reference client
// resolves it by trying a list of providers in order and falling back to an
// empty value, which is the same shape implemented here:
//
//   * ExternalProvider  - loads a user-supplied module that exports compute().
//   * PairDictProvider  - the community key-material dictionary the reference
//                         client fetches (value hardcoded as Base64 there).
//   * EmptyProvider     - sends no header.
//
// PairDictProvider downloads and caches the real key material. The per-request
// transform itself is NOT implemented here: it is a port of a live obfuscated
// bundle, and guessing at it would be dishonest. Supply it through
// X_TID_MODULE (see README) and the whole chain starts working.
import { log } from '../util.mjs';

export const DEFAULT_KEY_MATERIAL_URL =
  process.env.X_TID_KEY_MATERIAL_URL ??
  'https://raw.githubusercontent.com/fa0311/x-client-transaction-id-pair-dict/refs/heads/main/pair.json';

export const ONDEMAND_BUNDLE_URL =
  process.env.X_TID_ONDEMAND_URL ??
  'https://abs.twimg.com/responsive-web/client-web/ondemand.s.{filename}a.js';

export class TransactionIdUnavailableError extends Error {
  constructor(reason) {
    super(reason);
    this.name = 'TransactionIdUnavailableError';
  }
}

export class EmptyProvider {
  constructor() {
    this.name = 'empty';
  }

  async get() {
    return '';
  }
}

export class PairDictProvider {
  constructor(options = {}) {
    this.name = 'pair-dict';
    this.keyMaterialUrl = options.keyMaterialUrl ?? DEFAULT_KEY_MATERIAL_URL;
    this.compute = options.compute;
    this.ttlMs = options.ttlMs ?? 6 * 60 * 60 * 1000;
    this.keyMaterial = undefined;
    this.fetchedAt = 0;
    this.warned = false;
  }

  async loadKeyMaterial() {
    const fresh = this.keyMaterial !== undefined && Date.now() - this.fetchedAt < this.ttlMs;
    if (fresh) {
      return this.keyMaterial;
    }
    const response = await fetch(this.keyMaterialUrl, {
      headers: { accept: 'application/json' }
    });
    if (!response.ok) {
      throw new TransactionIdUnavailableError(`key_material_http_${response.status}`);
    }
    this.keyMaterial = await response.json();
    this.fetchedAt = Date.now();
    log('info', 'transaction-id key material refreshed');
    return this.keyMaterial;
  }

  invalidate() {
    this.keyMaterial = undefined;
    this.fetchedAt = 0;
  }

  async get(context) {
    const material = await this.loadKeyMaterial();
    if (typeof this.compute !== 'function') {
      if (!this.warned) {
        this.warned = true;
        log('warn',
          'transaction-id compute() is not configured; set X_TID_MODULE to enable the header');
      }
      throw new TransactionIdUnavailableError('compute_not_configured');
    }
    return this.compute({ material, method: context.method, path: context.path });
  }
}

export class ExternalProvider {
  constructor(module, name) {
    this.name = name ?? 'external';
    this.compute = module.compute;
  }

  async get(context) {
    if (typeof this.compute !== 'function') {
      throw new TransactionIdUnavailableError('module_missing_compute');
    }
    return this.compute(context);
  }
}

export class TransactionIdService {
  constructor(providers) {
    this.providers = providers;
  }

  // Never throws: the caller sends the request with or without the header,
  // exactly like the reference client's fallback path.
  async resolve(method, path) {
    for (const provider of this.providers) {
      try {
        const value = await provider.get({ method, path });
        if (typeof value === 'string' && value.length > 0) {
          return value;
        }
      } catch (error) {
        log('debug', `transaction-id provider '${provider.name}' failed`, { error: String(error) });
      }
    }
    return '';
  }
}

export async function createDefaultTransactionIdService() {
  const providers = [];
  const modulePath = process.env.X_TID_MODULE;
  if (modulePath && modulePath.length > 0) {
    try {
      const loaded = await import(modulePath);
      providers.push(new ExternalProvider(loaded, 'external-module'));
    } catch (error) {
      log('warn', 'X_TID_MODULE could not be loaded', { error: String(error) });
    }
  }
  if (process.env.X_TID_DISABLED !== '1') {
    providers.push(new PairDictProvider());
  }
  providers.push(new EmptyProvider());
  return new TransactionIdService(providers);
}
