import { app, BrowserWindow, Tray, Menu, ipcMain, dialog } from 'electron';
import { VPNManager } from './vpn/manager';
import { ConfigStore } from './store/config';
import { createTray } from './tray';
import { createMainWindow } from './window';
import { initializeCertificatePinning } from './security/init-certificate-pinning';

// API Configuration
// Set API_BASE_URL environment variable for production deployment
// Default: http://localhost:8080 (development only)
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8080';

// Validate API URL format and enforce HTTPS in production
try {
  const url = new URL(API_BASE_URL);

  // CRITICAL SECURITY: Enforce HTTPS in production
  if (process.env.NODE_ENV === 'production' && url.protocol !== 'https:') {
    throw new Error('Production builds MUST use HTTPS. HTTP is insecure and not allowed.');
  }
} catch (error) {
  console.error('[Main] Invalid or insecure API_BASE_URL:', API_BASE_URL);
  console.error('[Main] Error:', (error as Error).message);

  if (process.env.NODE_ENV === 'production') {
    // In production, fail hard - don't allow insecure connections
    console.error('[Main] FATAL: Cannot start app with insecure API URL in production');
    process.exit(1);
  } else {
    // In development, fall back to localhost
    console.error('[Main] Falling back to http://localhost:8080 (development only)');
    process.env.API_BASE_URL = 'http://localhost:8080';
  }
}

console.log('[Main] API Base URL:', API_BASE_URL);
console.log('[Main] Environment:', process.env.NODE_ENV || 'development');

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

// Helper function to wrap IPC handlers with error handling
const handleIPCError = (handler: (...args: any[]) => Promise<any>) => {
  return async (...args: any[]) => {
    try {
      return await handler(...args);
    } catch (error) {
      console.error('[Main] IPC Handler Error:', error);

      // Check if it's a backend connection error
      if (error instanceof Error && error.message.includes('fetch')) {
        return {
          success: false,
          error: 'Unable to connect to backend server. Please check if the server is running.',
          isNetworkError: true
        };
      }

      return {
        success: false,
        error: (error as Error).message || 'An unexpected error occurred'
      };
    }
  };
};

const setupIPCHandlers = () => {
  // Get API configuration
  ipcMain.handle('get-api-config', () => {
    return {
      apiBaseUrl: API_BASE_URL,
      isProduction: process.env.NODE_ENV === 'production'
    };
  });

  // Import .ovpn file
  ipcMain.handle('import-config', async () => {
    console.log('[Main] Import config requested');

    if (!mainWindow) {
      console.error('[Main] No main window available');
      return { success: false, error: 'Application window not available' };
    }

    try {
      const result = await dialog.showOpenDialog(mainWindow, {
        title: 'Select OpenVPN Configuration File',
        properties: ['openFile'],
        filters: [
          { name: 'OpenVPN Config', extensions: ['ovpn', 'conf'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      });

      console.log('[Main] Dialog result:', result);

      if (!result.canceled && result.filePaths.length > 0) {
        try {
          const configPath = result.filePaths[0];
          console.log('[Main] Importing config from:', configPath);

          await vpnManager.importConfig(configPath);
          console.log('[Main] Config imported successfully');

          return { success: true };
        } catch (error) {
          console.error('[Main] Import failed:', error);
          return { success: false, error: (error as Error).message };
        }
      }

      console.log('[Main] User cancelled dialog');
      return { success: false, error: 'No file selected' };
    } catch (error) {
      console.error('[Main] Dialog error:', error);
      return { success: false, error: (error as Error).message };
    }
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
  ipcMain.handle('vpn-get-status', async () => {
    return vpnManager.getStatus();
  });

  // Get VPN stats
  ipcMain.handle('vpn-get-stats', async () => {
    return vpnManager.getStats();
  });

  // Set VPN credentials
  ipcMain.handle('vpn-set-credentials', async (_, username: string, password: string) => {
    try {
      await vpnManager.setCredentials(username, password);
      return { success: true };
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  });

  // Check if config exists
  ipcMain.handle('has-config', async () => {
    return configStore.hasActiveConfig();
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
  ipcMain.handle('update-settings', (_, settings) => {
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

  // Authentication handlers with error handling
  ipcMain.handle('auth-send-otp', handleIPCError(async (_, email: string) => {
    const { authService } = await import('./auth/service');
    return await authService.sendOTP(email);
  }));

  ipcMain.handle('auth-verify-otp', handleIPCError(async (_, email: string, code: string) => {
    const { authService } = await import('./auth/service');
    return await authService.verifyOTP(email, code);
  }));

  ipcMain.handle('auth-create-account', handleIPCError(async (_, email: string, password: string, otpCode: string) => {
    const { authService } = await import('./auth/service');
    return await authService.createAccount(email, password, otpCode);
  }));

  ipcMain.handle('auth-login', handleIPCError(async (_, email: string, password: string) => {
    const { authService } = await import('./auth/service');
    return await authService.login(email, password);
  }));

  ipcMain.handle('auth-logout', handleIPCError(async () => {
    const { authService } = await import('./auth/service');
    await authService.logout();
    return { success: true };
  }));

  ipcMain.handle('auth-is-authenticated', handleIPCError(async () => {
    const { authService } = await import('./auth/service');
    return authService.isAuthenticated();
  }));

  ipcMain.handle('auth-get-current-user', handleIPCError(async () => {
    const { authService } = await import('./auth/service');
    return authService.getCurrentUser();
  }));

  // VPN status updates
  vpnManager.on('status-changed', (status) => {
    mainWindow?.webContents.send('vpn-status-changed', status);
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
  tray.setToolTip(status.connected ? 'BarqNet - Connected' : 'BarqNet - Disconnected');
};

app.whenReady().then(() => {
  // Initialize certificate pinning BEFORE any network requests
  // This protects against MITM attacks by validating server certificates
  initializeCertificatePinning();

  // Then initialize the rest of the application
  init();
});

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
