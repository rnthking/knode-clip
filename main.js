// KnodeClip 跨平台（Windows / macOS / Linux）：托盘常驻 + 全局热键。
// 抓取方式：按热键时模拟一次 Ctrl/⌘+C（mac=osascript，win=PowerShell SendKeys，linux=xdotool），
// 读剪贴板上传到 /spark/clip，再还原用户原剪贴板。不引入原生编译模块，CI 最稳。
const { app, Tray, Menu, globalShortcut, clipboard, BrowserWindow, ipcMain, Notification, nativeImage, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');

const BASE = 'https://spark.ithinkai.cn';
const HOTKEY = 'CommandOrControl+Shift+K';
const ICON = path.join(__dirname, 'build', 'icon.png');
const CFG_PATH = path.join(app.getPath('userData'), 'knode-clip.json');

let cfg = { token: '', mode: 'direct', dsKey: '' };
try { Object.assign(cfg, JSON.parse(fs.readFileSync(CFG_PATH, 'utf8'))); } catch (e) {}
function saveCfg() { try { fs.writeFileSync(CFG_PATH, JSON.stringify(cfg)); } catch (e) {} }

if (!app.requestSingleInstanceLock()) { app.quit(); }

let tray = null, loginWin = null;

function notify(body) { try { new Notification({ title: 'KNode 划线', body }).show(); } catch (e) {} }

app.whenReady().then(() => {
  if (process.platform === 'darwin' && app.dock) app.dock.hide(); // 仅托盘，无 Dock 图标
  createTray();
  globalShortcut.register(HOTKEY, captureAndSend);
  fetchAIKey();
});
app.on('window-all-closed', () => { /* 常驻托盘，不随窗口关闭退出 */ });
app.on('will-quit', () => { globalShortcut.unregisterAll(); });

function trayImage() {
  let img = nativeImage.createFromPath(ICON);
  if (!img.isEmpty()) { const s = process.platform === 'darwin' ? 18 : 16; img = img.resize({ width: s, height: s }); }
  return img;
}
function createTray() {
  tray = new Tray(trayImage());
  tray.setToolTip('KNode 划线 · ' + HOTKEY + ' 收集');
  refreshMenu();
}
function refreshMenu() {
  const loggedIn = !!cfg.token;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'KNode 划线 · ' + (loggedIn ? '已登录' : '未登录'), enabled: false },
    { type: 'separator' },
    { label: '收集选中文字（' + HOTKEY + '）', click: captureAndSend },
    { label: '收集模式', submenu: [
      { label: '直接收集（原文存卡）', type: 'radio', checked: cfg.mode !== 'ai', click: () => { cfg.mode = 'direct'; saveCfg(); } },
      { label: 'AI 解读（DeepSeek）', type: 'radio', checked: cfg.mode === 'ai', click: () => { cfg.mode = 'ai'; saveCfg(); } },
    ] },
    { type: 'separator' },
    loggedIn ? { label: '退出登录', click: () => { cfg.token = ''; saveCfg(); refreshMenu(); } }
             : { label: '登录…', click: openLogin },
    { label: '打开 KNode 网页', click: () => shell.openExternal(BASE) },
    { type: 'separator' },
    { label: '退出 KnodeClip', click: () => app.quit() },
  ]));
}

function openLogin() {
  if (loginWin) { loginWin.focus(); return; }
  loginWin = new BrowserWindow({
    width: 340, height: 320, resizable: false, title: '登录 KNode',
    webPreferences: { preload: path.join(__dirname, 'preload.js') },
  });
  loginWin.setMenuBarVisibility(false);
  loginWin.loadFile('login.html');
  loginWin.on('closed', () => { loginWin = null; });
}

ipcMain.handle('login', async (e, { email, password }) => {
  try {
    const r = await fetch(BASE + '/spark/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    const j = await r.json();
    if (j && j.code === 0 && j.data && j.data.token) { cfg.token = j.data.token; saveCfg(); refreshMenu(); fetchAIKey(); return { ok: true }; }
    return { ok: false, msg: (j && j.msg) || '登录失败' };
  } catch (err) { return { ok: false, msg: '网络错误' }; }
});
ipcMain.on('login-done', () => { if (loginWin) loginWin.close(); });

// 模拟一次复制（把选区送进剪贴板），跨平台
function synthCopy(cb) {
  let cmd;
  if (process.platform === 'darwin') cmd = `osascript -e 'tell application "System Events" to keystroke "c" using command down'`;
  else if (process.platform === 'win32') cmd = `powershell -NoProfile -Command "$w=New-Object -ComObject WScript.Shell; $w.SendKeys('^c')"`;
  else cmd = 'xdotool key --clearmodifiers ctrl+c';
  exec(cmd, () => setTimeout(cb, 220));
}

function captureAndSend() {
  if (!cfg.token) { notify('请先登录'); openLogin(); return; }
  const saved = clipboard.readText();
  synthCopy(async () => {
    const text = (clipboard.readText() || '').trim();
    setTimeout(() => { try { clipboard.writeText(saved); } catch (e) {} }, 120); // 还原原剪贴板
    if (!text) { notify('没选中文字（先选中再按热键）'); return; }
    try {
      const r = await fetch(BASE + '/spark/clip', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + cfg.token },
        body: JSON.stringify({ text, source: 'KnodeClip', sourceTitle: 'KnodeClip', mode: cfg.mode === 'ai' ? 'ai' : 'direct' }),
      });
      const j = await r.json();
      if (j && j.code === 0) notify('✓ 已收集' + (cfg.mode === 'ai' ? '（AI 解读）' : ''));
      else if (j && j.code === 401) { cfg.token = ''; saveCfg(); refreshMenu(); notify('登录已过期，请重新登录'); }
      else notify((j && j.msg) || '上传失败');
    } catch (e) { notify('网络错误'); }
  });
}

// 同步后台下发的 DeepSeek Key（与 Web 同源；目前 AI 解读在 Web 完成，这里先缓存备用）
function fetchAIKey() {
  fetch(BASE + '/spark/ai-key').then(r => r.json()).then(j => {
    const k = j && j.code === 0 && j.data && j.data.key;
    if (k) { cfg.dsKey = k; saveCfg(); }
  }).catch(() => {});
}
