// User agent for X's web surface.
//
// The cookie session is only accepted while a request still looks like a
// mobile browser, so the browser shell stays fixed and only the device token
// is read from the running hardware instead of being spelled out by hand.
//
// deviceInfo reports the literal "default" for fields the platform has not
// configured yet (emulators, non-production builds), hence the fallback.
import { deviceInfo } from '@kit.BasicServicesKit';

// Platform and engine tokens the rest of the client also advertises: the
// sec-ch-ua hints in XPrivateClient quote the same Chromium major, so they
// have to move together.
const ANDROID_VERSION_TOKEN: string = 'Android 14';
const CHROME_VERSION_TOKEN: string = '126.0.0.0';

// Value the platform returns when it has no real model to report.
const UNCONFIGURED_DEVICE_MODEL: string = 'default';

// Stated device when the hardware has none of its own. A device token that
// matches no real handset is itself a fingerprint, so this stays a plausible
// model rather than a placeholder.
const FALLBACK_DEVICE_MODEL: string = 'Pixel 8';

// Drops the characters that frame the platform comment. A model carrying a
// ')' or ';' would end the comment early and stop the string parsing as a
// browser user agent.
function sanitizedModelToken(value: string): string {
  let result: string = '';
  for (let index = 0; index < value.length; index++) {
    const character: string = value.charAt(index);
    const code: number = value.charCodeAt(index);
    const isControl: boolean = code < 0x20 || code === 0x7f;
    const isDelimiter: boolean = character === '(' || character === ')' ||
      character === ';' || character === '\\';
    if (!isControl && !isDelimiter) {
      result += character;
    }
  }
  return result.trim();
}

class XUserAgent {
  private cachedValue: string = '';
  private resolvedModel: string = '';

  // Device information is constant for the process lifetime, so it is read
  // once and reused across every request.
  private deviceModel(): string {
    if (this.resolvedModel.length === 0) {
      const reported: string = sanitizedModelToken(deviceInfo.productModel);
      const isUsable: boolean = reported.length > 0 &&
        reported.toLowerCase() !== UNCONFIGURED_DEVICE_MODEL;
      this.resolvedModel = isUsable ? reported : FALLBACK_DEVICE_MODEL;
    }
    return this.resolvedModel;
  }

  value(): string {
    if (this.cachedValue.length === 0) {
      this.cachedValue = 'Mozilla/5.0 (Linux; ' + ANDROID_VERSION_TOKEN + '; ' +
        this.deviceModel() + ') AppleWebKit/537.36 (KHTML, like Gecko) ' +
        'Chrome/' + CHROME_VERSION_TOKEN + ' Mobile Safari/537.36';
    }
    return this.cachedValue;
  }

  // Exposed for diagnostics so the resolved model can be logged on its own.
  model(): string {
    return this.deviceModel();
  }
}

export const xUserAgent = new XUserAgent();
