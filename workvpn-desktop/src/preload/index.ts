import { contextBridge, ipcRenderer } from 'electron';

// Expose environment info to renderer
contextBridge.exposeInMainWorld('env', {
  NODE_ENV: process.env.NODE_ENV || 'development',
  isDevelopment: process.env.NODE_ENV !== 'production',
  isProduction: process.env.NODE_ENV === 'production',
});

// Expose safe IPC methods to renderer
contextBridge.exposeInMainWorld('vpn', {
  // API Configuration
  getApiConfig: () => ipcRenderer.invoke('get-api-config'),

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
  setCredentials: (username: string, password: string) => ipcRenderer.invoke('vpn-set-credentials', username, password),

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
  },

  // Authentication
  sendOTP: (email: string) => ipcRenderer.invoke('auth-send-otp', email),
  verifyOTP: (email: string, code: string) => ipcRenderer.invoke('auth-verify-otp', email, code),
  createAccount: (email: string, password: string, otpCode: string) => ipcRenderer.invoke('auth-create-account', email, password, otpCode),
  login: (email: string, password: string) => ipcRenderer.invoke('auth-login', email, password),
  logout: () => ipcRenderer.invoke('auth-logout'),
  isAuthenticated: () => ipcRenderer.invoke('auth-is-authenticated'),
  getCurrentUser: () => ipcRenderer.invoke('auth-get-current-user')
});
