const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('knode', {
  login: (email, password) => ipcRenderer.invoke('login', { email, password }),
  done: () => ipcRenderer.send('login-done'),
});
