// EraRelay 前端布局探针 —— 在**指定分辨率**下量真实 DOM 几何并出图。
//
// 用途：改前端 CSS 之后、上真机之前，先在这一层拿到**可核对的像素/几何证据**。
// 起因（research/43 §6）：真机不在手边时，我们只能"改完靠猜"，而这正是 R 角与
// 右半边两次翻车的共同原因。本探针用无头 Chrome 复刻真机分辨率，直接读元素几何。
//
// 前置（由 web-layout-probe.ps1 编排，或手工）：
//   ① EraCore.Cli --server --port 8080 且已 load-game
//   ② vite dev（EraCore.Web，5173）
//   ③ Chrome --headless=new --remote-debugging-port=9333 --window-size=W,H
//
// 用法：node web-layout-probe.mjs [--width 1920] [--height 1200] [--out <目录>] [--prefix <前缀>]
//
// 输出：<out>/<prefix>-1-inputbar-hidden.png   输入栏收起（常态）
//       <out>/<prefix>-2-inputbar-shown.png    点 ⌨ 之后（输入栏展开）
//       <out>/<prefix>-3-hint-probe.png        注入一颗借真实 scoped 样式的提示条
//       stdout 的 JSON：各元素 boundingClientRect
import fs from 'node:fs';
import path from 'node:path';

/** 极简参数解析——避免为一个探针引入依赖。 */
function arg(name, dflt) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const W = Number(arg('width', '1920'));
const H = Number(arg('height', '1200'));
// ★ 默认输出目录**不写死本机路径**（原为硬编码的本机绝对路径，含用户名）—— 那是外发红线之一。
//   改为：显式 --out > 环境变量 OUT_DIR > 当前工作目录下的 layout-shots。换机 / 外发都不踩空。
const OUT = arg('out', process.env.OUT_DIR || path.join(process.cwd(), 'layout-shots'));
const PREFIX = arg('prefix', 'probe');
const PORT = Number(arg('cdp-port', '9333'));

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = list.find((t) => t.type === 'page' && t.url.includes('5173'));
if (!page) {
  console.error('✗ 没找到 5173 的页面目标。现有：', list.map((t) => `${t.type} ${t.url}`));
  process.exit(1);
}
const ws = new WebSocket(page.webSocketDebuggerUrl);
let seq = 0;
const waiting = new Map();
ws.addEventListener('message', (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && waiting.has(m.id)) {
    const { res, rej } = waiting.get(m.id);
    waiting.delete(m.id);
    if (m.error) rej(new Error(JSON.stringify(m.error)));
    else res(m.result);
  }
});
await new Promise((r) => ws.addEventListener('open', r));

function send(method, params = {}) {
  return new Promise((res, rej) => {
    const id = ++seq;
    waiting.set(id, { res, rej });
    ws.send(JSON.stringify({ id, method, params }));
  });
}
async function js(expression) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error('页面内报错: ' + JSON.stringify(r.exceptionDetails));
  return r.result.value;
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(`${OUT}\\${name}.png`, Buffer.from(r.data, 'base64'));
  console.log(`   存图 ${name}.png`);
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: W, height: H, deviceScaleFactor: 1, mobile: true,
});

for (let i = 0; i < 60; i++) {
  const n = await js(`document.querySelectorAll('.term-line').length`).catch(() => 0);
  if (n > 3) { console.log(`  终端已出内容（${n} 行）`); break; }
  await sleep(500);
}

/** 几何探针——量的是「元素实际占的框」，不是样式声明值。 */
const PROBE = `(() => {
  const box = (s) => { const e = document.querySelector(s); if (!e) return null;
    const r = e.getBoundingClientRect();
    return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }; };
  const btns = [...document.querySelectorAll('.term-line button')].map(e => {
    const r = e.getBoundingClientRect();
    return { t: e.textContent.trim().slice(0, 24), x: Math.round(r.x), r: Math.round(r.right) };
  });
  return {
    viewport: [innerWidth, innerHeight],
    gameWindow: box('.terminal-content'),
    inputBar: box('.input-bar'),
    hint: box('.overlay-hint'),
    buttons: btns,
    buttonsRightMost: btns.length ? Math.max(...btns.map(b => b.r)) : null,
  };
})()`;

console.log(`--- ① 输入栏收起（${W}x${H}）`);
console.log('  ', JSON.stringify(await js(PROBE)));
await shot(`${PREFIX}-1-inputbar-hidden`);

const clicked = await js(`(() => {
  const b = document.querySelector('.game-shell-controls .icon-btn');
  if (!b) return false;
  b.click(); return true;
})()`);
await sleep(700);
if (clicked) {
  console.log('--- ② 点 ⌨ 之后（输入栏展开）');
  console.log('  ', JSON.stringify(await js(PROBE)));
  await shot(`${PREFIX}-2-inputbar-shown`);
  await js(`document.querySelector('.game-shell-controls .icon-btn').click(), 1`);
  await sleep(600);
} else {
  console.log('--- ② 跳过：页面上没有 ⌨ 按钮（可能停在游戏列表页）');
}

// 借真实 scoped 样式注入一颗提示条——.overlay-hint 只在 AnyKey/EnterKey 才渲染，
// 标题页量不到；借父容器的 data-v-* 属性复制样式，能量到它的真实位置。
console.log('--- ③ 提示条位置（借真实 scoped 样式注入）');
const hash = await js(`(() => {
  const tv = document.querySelector('.terminal-view'); if (!tv) return null;
  const h = [...tv.attributes].map(a => a.name).find(n => n.startsWith('data-v-'));
  const old = document.getElementById('probe-hint'); if (old) old.remove();
  const el = document.createElement('div');
  el.id = 'probe-hint'; el.className = 'overlay-hint';
  if (h) el.setAttribute(h, '');
  el.textContent = '点任意处继续';
  tv.appendChild(el);
  return h;
})()`);
await sleep(300);
console.log('   scoped 哈希 =', hash);
console.log('  ', JSON.stringify(await js(PROBE)));
await shot(`${PREFIX}-3-hint-probe`);
await js(`document.getElementById('probe-hint')?.remove(), 1`);

ws.close();
