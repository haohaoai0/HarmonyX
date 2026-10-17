// Last-known-good response bodies for the private read operations.
//
// Stored as plain files under the app cache directory: preference values have a
// size ceiling and a timeline page comfortably exceeds it. Only the first page
// of an operation is cached, which keeps the entry count bounded and is exactly
// the page a cold start wants.
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Cache';
const DIRECTORY = 'response-cache';

export class ResponseCache {
  private static directory(context: common.Context): string {
    return context.cacheDir + '/' + DIRECTORY;
  }

  // Filesystem-safe, stable name for an operation + variables pair.
  private static fileName(key: string): string {
    let hash: number = 0x811c9dc5;
    for (let i: number = 0; i < key.length; i++) {
      hash = hash ^ key.charCodeAt(i);
      hash = (hash * 0x01000193) >>> 0;
    }
    return hash.toString(16) + '_' + key.length.toString();
  }

  static save(context: common.Context, key: string, body: string): void {
    if (body.length === 0) {
      return;
    }
    let file: fs.File | undefined = undefined;
    try {
      const directory: string = ResponseCache.directory(context);
      if (!fs.accessSync(directory)) {
        fs.mkdirSync(directory);
      }
      const path: string = directory + '/' + ResponseCache.fileName(key);
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, Date.now().toString() + '\n' + body);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache write failed: %{public}s', JSON.stringify(error));
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (error) {
          // A descriptor that is already gone is not a problem here.
        }
      }
    }
  }

  // Returns the cached body, or '' when there is nothing usable.
  static load(context: common.Context, key: string): string {
    try {
      const path: string = ResponseCache.directory(context) + '/' + ResponseCache.fileName(key);
      if (!fs.accessSync(path)) {
        return '';
      }
      const content: string = fs.readTextSync(path);
      const separator: number = content.indexOf('\n');
      if (separator <= 0 || separator >= content.length - 1) {
        return '';
      }
      return content.substring(separator + 1);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache read failed: %{public}s', JSON.stringify(error));
      return '';
    }
  }
}
