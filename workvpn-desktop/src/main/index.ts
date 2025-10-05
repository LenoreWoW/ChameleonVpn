import { app, BrowserWindow, Tray, Menu, ipcMain, dialog } from 'electron';
import path from 'path';
import { VPNManager } from './vpn/manager';
import { ConfigStore } from './store/config';
import { createTray } from './tray';
import { createMainWindow } from './window';

// Handle creating/removing shortcuts on Windows when installing/uninstalling
if (require('electron-squirrel-startup')) {
  app.quit();
}

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let vpnManager: VPNManager;
let configStore: ConfigStore;

const init = async () => {
  // Initialize stores
  configStore = new ConfigStore();

  // Initialize VPN manager
  vpnManager = new VPNManager(configStore);

  // Create window
  mainWindow = createMainWindow();

  // Create system tray
  tray = createTray(mainWindow, vpnManager);

  // Setup IPC handlers
  setupIPCHandlers();

  // Check for auto-connect
  const autoConnect = configStore.get('autoConnect');
  if (autoConnect && configStore.hasActiveConfig()) {
    await vpnManager.connect();
  }
};

const setupIPCHandlers = () => {
  // Import .ovpn file
  ipcMain.handle('import-config', async () => {
    const result = await dialog.showOpenDialog(mainWindow!, {
      properties: ['openFile'],
      filters: [
        { name: 'OpenVPN Config', extensions: ['ovpn', 'conf'] }
      ]
    });

    if (!result.canceled && result.filePaths.length > 0) {
      try {
        const configPath = result.filePaths[0];
        await vpnManager.importConfig(configPath);
        return { success: true };
      } catch (error) {
        return { success: false, error: (error as Error).message };
      }
    }

    return { success: false, error: 'No file selected' };
  });

  // Connect VPN
  ipcMain.handle('vpn-connect', async () => {
    try {
      await vpnManager.connect();
      return { success: true };
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  // Disconnect VPN
  ipcMain.handle('vpn-disconnect', async () => {
    try {
      await vpnManager.disconnect();
      return { success: true };
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  // Get VPN status
  ipcMain.handle('vpn-status', async () => {
    return vpnManager.getStatus();
  });

  // Get config info
  ipcMain.handle('get-config-info', async () => {
    return vpnManager.getConfigInfo();
  });

  // Delete config
  ipcMain.handle('delete-config', async () => {
    try {
      await vpnManager.deleteConfig();
      return { success: true };
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  // Get settings
  ipcMain.handle('get-settings', () => {
    return {
      autoConnect: configStore.get('autoConnect') || false,
      autoStart: configStore.get('autoStart') || false,
      killSwitch: configStore.get('killSwitch') || false,
    };
  });

  // Save settings
  ipcMain.handle('save-settings', (_, settings) => {
    configStore.set('autoConnect', settings.autoConnect);
    configStore.set('autoStart', settings.autoStart);
    configStore.set('killSwitch', settings.killSwitch);

    // Handle auto-start
    if (settings.autoStart) {
      app.setLoginItemSettings({
        openAtLogin: true,
        openAsHidden: true
      });
    } else {
      app.setLoginItemSettings({
        openAtLogin: false
      });
    }

    return { success: true };
  });

  // Authentication handlers
  ipcMain.handle('auth-send-otp', async (_, phoneNumber: string) => {
    try {
      const { authService } = await import('./auth/service');
      return await authService.sendOTP(phoneNumber);
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  ipcMain.handle('auth-verify-otp', async (_, phoneNumber: string, code: string) => {
    try {
      const { authService } = await import('./auth/service');
      return await authService.verifyOTP(phoneNumber, code);
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  ipcMain.handle('auth-create-account', async (_, phoneNumber: string, password: string) => {
    try {
      const { authService } = await import('./auth/service');
      return await authService.createAccount(phoneNumber, password);
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  ipcMain.handle('auth-login', async (_, phoneNumber: string, password: string) => {
    try {
      const { authService } = await import('./auth/service');
      return await authService.login(phoneNumber, password);
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  ipcMain.handle('auth-logout', async () => {
    try {
      const { authService } = await import('./auth/service');
      await authService.logout();
    } catch (error) {
      console.error('Logout error:', error);
    }
  });

  ipcMain.handle('auth-is-authenticated', async () => {
    try {
      const { authService } = await import('./auth/service');
      return authService.isAuthenticated();
    } catch (error) {
      return false;
    }
  });

  ipcMain.handle('auth-get-current-user', async () => {
    try {
      const { authService } = await import('./auth/service');
      return authService.getCurrentUser();
    } catch (error) {
      return null;
    }
  });

  // VPN status updates
  vpnManager.on('status-changed', (status) => {
    mainWindow?.webContents.send('vpn-status-update', status);
    updateTrayMenu(status);
  });

  vpnManager.on('stats-update', (stats) => {
    mainWindow?.webContents.send('vpn-stats-update', stats);
  });
};

const updateTrayMenu = (status: any) => {
  if (!tray) return;

  const contextMenu = Menu.buildFromTemplate([
    {
      label: status.connected ? 'Disconnect' : 'Connect',
      click: () => {
        if (status.connected) {
          vpnManager.disconnect();
        } else {
          vpnManager.connect();
        }
      },
      enabled: configStore.hasActiveConfig()
    },
    {
      label: 'Show Window',
      click: () => {
        mainWindow?.show();
      }
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.quit();
      }
    }
  ]);

  tray.setContextMenu(contextMenu);
  tray.setToolTip(status.connected ? 'WorkVPN - Connected' : 'WorkVPN - Disconnected');
};

app.whenReady().then(init);

app.on('window-all-closed', () => {
  // Don't quit, keep running in tray
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    mainWindow = createMainWindow();
  }
});

app.on('before-quit', async () => {
  // Disconnect VPN before quitting
  if (vpnManager.getStatus().connected) {
    await vpnManager.disconnect();
  }
});
