const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const TouchType = { Down: 0, Up: 1, Move: 2, Cancel: 3 };
const source = fs.readFileSync('entry/src/main/ets/components/TweetCard.ets', 'utf8')
  .replace('struct TweetCard', 'class TweetCard');
const tree = ts.createSourceFile('card.ts', source, ts.ScriptTarget.Latest, true);
const card = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'TweetCard');
const names = ['onCardTouch', 'releaseCardPress', 'aboutToDisappear'];
const body = names.map(name => card.members.find(n => ts.isMethodDeclaration(n)
  && n.name.getText(tree) === name).getText(tree)).join('\n');
const constants = tree.statements.filter(n => ts.isVariableStatement(n)
  && n.declarationList.declarations.some(d => d.name.getText(tree) === 'CARD_PRESS_MOVE_SLOP'))
  .map(n => n.getText(tree)).join('\n');
const output = ts.transpileModule(constants + '\nclass Card {' + body + '}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Card = new Function('TouchType', 'motionDuration', 'motionCurve', 'motionScale', 'LIST_ITEM_PRESS_SCALE',
  output + ';return Card;')(TouchType, n => n, () => 'curve', n => n, 0.95);

function createCard() {
  const card = Object.assign(new Card(), { pressEffectEnabled: true, reduceMotion: false,
    pressScale: 1, pressTracking: false, pressStartX: 0, pressStartY: 0, saveReadingState() {} });
  card.getUIContext = () => ({ animateTo: (_options, update) => update() });
  return card;
}
function touch(type, x = 100, y = 200, count = 1) {
  return { type, touches: Array.from({ length: count }, () => ({ windowX: x, windowY: y })) };
}

test('stationary press sinks the card and both release and cancel restore its scale', () => {
  for (const end of [TouchType.Up, TouchType.Cancel]) {
    const card = createCard();
    card.onCardTouch(touch(TouchType.Down));
    assert.equal(card.pressScale, 0.95);
    card.onCardTouch(touch(TouchType.Move, 103, 202));
    assert.equal(card.pressScale, 0.95);
    card.onCardTouch(touch(end, 103, 202, 0));
    assert.equal(card.pressScale, 1);
    assert.equal(card.pressTracking, false);
  }
});

test('vertical, horizontal and diagonal drags cancel sinking until the next press', () => {
  for (const [x, y] of [[100, 210], [110, 200], [106, 206]]) {
    const card = createCard();
    card.onCardTouch(touch(TouchType.Down));
    card.onCardTouch(touch(TouchType.Move, x, y));
    assert.equal(card.pressScale, 1);
    card.onCardTouch(touch(TouchType.Move));
    assert.equal(card.pressScale, 1, 'moving back must not restart the press effect');
    card.onCardTouch(touch(TouchType.Up, 100, 200, 0));
    card.onCardTouch(touch(TouchType.Down));
    assert.equal(card.pressScale, 0.95);
  }
});

test('disabled effects, reduced motion and multi-touch cannot leave a pressed card behind', () => {
  for (const setting of ['pressEffectEnabled', 'reduceMotion']) {
    const card = createCard();
    card.onCardTouch(touch(TouchType.Down));
    card[setting] = setting === 'reduceMotion';
    card.onCardTouch(touch(TouchType.Move));
    assert.equal(card.pressScale, 1);
    card.onCardTouch(touch(TouchType.Down));
    assert.equal(card.pressScale, 1);
  }
  const card = createCard();
  card.onCardTouch(touch(TouchType.Down));
  card.onCardTouch(touch(TouchType.Down, 100, 200, 2));
  assert.equal(card.pressScale, 1);
  card.onCardTouch(touch(TouchType.Move));
  assert.equal(card.pressScale, 1);
});

test('leaving a lazy cell resets press feedback before it can be shown again', () => {
  const card = createCard();
  card.onCardTouch(touch(TouchType.Down));
  card.aboutToDisappear();
  assert.equal(card.pressScale, 1);
  assert.equal(card.pressTracking, false);
});
