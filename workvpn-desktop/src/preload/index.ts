import { contextBridge, ipcRenderer } from 'electron';

// Expose safe IPC methods to renderer
contextBridge.exposeInMainWorld('vpn', {
  // Config management
  importConfig: () => ipcRenderer.invoke('import-config'),
  hasConfig: () => ipcRenderer.invoke('has-config'),
  getConfigInfo: () => ipcRenderer.invoke('get-config-info'),
  deleteConfig: () => ipcRenderer.invoke('delete-config'),

  // Connection control
  connect: () => ipcRenderer.invoke('vpn-connect'),
  disconnect: () => ipcRenderer.invoke('vpn-disconnect'),
  getStatus: () => ipcRenderer.invoke('vpn-get-status'),
  getStats: () => ipcRenderer.invoke('vpn-get-stats'),

  // Settings
  getSettings: () => ipcRenderer.invoke('get-settings'),
  updateSettings: (settings: any) => ipcRenderer.invoke('update-settings', settings),

  // Event listeners
  onStatusChanged: (callback: (status: any) => void) => {
    ipcRenderer.on('vpn-status-changed', (_event, status) => callback(status));
  },

  onStatsUpdate: (callback: (stats: any) => void) => {
    ipcRenderer.on('vpn-stats-update', (_event, stats) => callback(stats));
  },

  onConfigDeleted: (callback: () => void) => {
    ipcRenderer.on('vpn-config-deleted', () => callback());
  },

  // Listen for import dialog trigger
  onShowImportDialog: (callback: () => void) => {
    ipcRenderer.on('show-import-dialog', () => callback());
  }
});
