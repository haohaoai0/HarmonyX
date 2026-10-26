const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(name, dependencies = {}, globals = {}) {
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/' + name + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('exports', 'require', ...Object.keys(globals), code)(exports, name => dependencies[name] ?? {}, ...Object.values(globals));
  return exports;
}
const { MediaViewerNavigationReturn, mediaViewerNavigationTransition } = load('MediaViewerNavigation', {}, {
  NavigationOperation: { PUSH: 'push', POP: 'pop' }
});

test('shared-media return waits until Navigation reveals the previous page and finishes the same native pop once', () => {
  const order = [], controller = new MediaViewerNavigationReturn();
  controller.attach({ navDestinationId: 'photo-page' });
  assert.equal(controller.request(() => {
    assert.equal(order.at(-1), 'source-visible');
    order.push('shrink-media');
    assert.equal(controller.request(() => assert.fail('recursive return'), () => assert.fail('second pop')), false);
  }, () => order.push('native-pop')), true);
  assert.deepEqual(order, ['native-pop']);
  assert.equal(controller.request(() => assert.fail('second close'), () => assert.fail('second pop')), true);
  const transition = mediaViewerNavigationTransition({ navDestinationId: 'photo-page' }, 'pop');
  order.push('source-visible');
  transition.transition({ finishTransition: () => order.push('finish-native-pop') });
  assert.deepEqual(order, ['native-pop', 'source-visible', 'shrink-media']);
  assert.equal(controller.complete(), true); assert.equal(controller.complete(), true);
  assert.equal(order.filter(item => item === 'finish-native-pop').length, 1);
  transition.onTransitionEnd(true); controller.detach();
  assert.equal(mediaViewerNavigationTransition({ navDestinationId: 'photo-page' }, 'pop'), undefined);
});

test('normal destinations, pushes and a detached media visit never intercept an unrelated navigation', () => {
  const controller = new MediaViewerNavigationReturn();
  assert.equal(controller.request(() => assert.fail(), () => assert.fail()), false);
  controller.attach({ navDestinationId: 'video-page' });
  assert.equal(mediaViewerNavigationTransition({ navDestinationId: 'video-page' }, 'pop'), undefined);
  controller.request(() => assert.fail('detached action'), () => {});
  assert.equal(mediaViewerNavigationTransition({ navDestinationId: 'video-page' }, 'push'), undefined);
  controller.detach();
  assert.equal(controller.complete(), false);
  assert.equal(mediaViewerNavigationTransition({ navDestinationId: 'video-page' }, 'pop'), undefined);
});

test('copy confirmation is shown only after the clipboard write succeeds; failures are reported', async () => {
  const trace = []; let resolve, reject;
  const { copyPostLink } = load('PostLinkCopy', { '@kit.BasicServicesKit': { pasteboard: {
    MIMETYPE_TEXT_PLAIN: 'text/plain', createData: (kind, value) => ({ kind, value }),
    getSystemPasteboard: () => ({ setData(data) {
      trace.push(data); return new Promise((done, fail) => { resolve = done; reject = fail; });
    } })
  } } }, { $r: key => key });
  const context = { getPromptAction: () => ({ showToast: options => trace.push(options.message) }) };
  const pending = copyPostLink(context, 'https://example.com/expanded');
  assert.equal(trace.length, 1); resolve(); await pending;
  assert.equal(trace.at(-1), 'app.string.photo_copied');
  const failed = copyPostLink(context, 'https://example.com/expanded'); reject(new Error('clipboard unavailable')); await failed;
  assert.equal(trace.at(-1), 'app.string.photo_copy_failed');
  const count = trace.length; await copyPostLink(context, ''); assert.equal(trace.length, count);
});

test('media title bars request the native immersive material only on supported API levels', () => {
  let supported = true;
  const { mediaViewerTitleBarStyle } = load('MediaViewerTitleBar', {
    '@kit.UIDesignKit': { hdsMaterial: { MaterialType: { IMMERSIVE: 'immersive' }, MaterialLevel: { ADAPTIVE: 'adaptive' } } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => supported } }
  }, { Color: { Transparent: 'transparent' }, $r: key => key });
  const immersive = mediaViewerTitleBarStyle();
  assert.deepEqual(immersive.systemMaterialEffect, { materialType: 'immersive', materialLevel: 'adaptive' });
  assert.equal(immersive.originalStyle.contentStyle.menuStyle.backgroundColor, undefined);
  assert.equal(immersive.originalStyle.contentStyle.backIconStyle.backgroundColor, undefined);
  supported = false; assert.equal(mediaViewerTitleBarStyle().systemMaterialEffect, undefined);
});
