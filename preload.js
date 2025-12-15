const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  selectFolder: () => ipcRenderer.invoke('select-folder'),
  openFolder: (folderPath) => ipcRenderer.invoke('open-folder', folderPath),
  startWatcher: () => ipcRenderer.invoke('start-watcher'),
  stopWatcher: () => ipcRenderer.invoke('stop-watcher'),
  getWatcherStatus: () => ipcRenderer.invoke('get-watcher-status'),
  onWatcherStatus: (callback) => ipcRenderer.on('watcher-status', (event, status) => callback(status)),
  onWatcherError: (callback) => ipcRenderer.on('watcher-error', (event, error) => callback(error)),
  onWatcherOutput: (callback) => ipcRenderer.on('watcher-output', (event, output) => callback(output))
});