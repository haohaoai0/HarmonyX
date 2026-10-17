import { appTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// A local SDK override lets the IDE and CLI share a repaired SDK without
// changing the protected DevEco Studio installation or committing host paths.
const localPropertiesPath: string = path.resolve(__dirname, 'local.properties');
if (fs.existsSync(localPropertiesPath)) {
  const localProperties: string = fs.readFileSync(localPropertiesPath, 'utf8');
  const sdkMatch: RegExpMatchArray | null = localProperties.match(/^harmonyx\.sdk\.dir\s*=\s*(.+)$/m);
  if (sdkMatch !== null && fs.existsSync(path.join(sdkMatch[1].trim(), 'default', 'sdk-pkg.json'))) {
    process.env.DEVECO_SDK_HOME = sdkMatch[1].trim();
  }
}

export default {
  system: appTasks,
  plugins: []
};
