import { Tray, Menu, nativeImage, BrowserWindow } from 'electron';
import path from 'path';
import { VPNManager } from './vpn/manager';

export function createTray(mainWindow: BrowserWindow, vpnManager: VPNManager): Tray {
  const iconPath = path.join(__dirname, '../../assets/icon.png');
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });

  const tray = new Tray(icon);

  const updateMenu = () => {
    const status = vpnManager.getStatus();

    const contextMenu = Menu.buildFromTemplate([
      {
        label: status.connected ? '🟢 Connected' : '🔴 Disconnected',
        enabled: false
      },
      { type: 'separator' },
      {
        label: status.connected ? 'Disconnect' : 'Connect',
        click: () => {
          if (status.connected) {
            vpnManager.disconnect();
          } else {
            vpnManager.connect();
          }
        },
        enabled: vpnManager.hasConfig()
      },
      { type: 'separator' },
      {
        label: 'Show Window',
        click: () => {
          mainWindow.show();
          mainWindow.focus();
        }
      },
      {
        label: 'Import Config...',
        click: () => {
          mainWindow.show();
          mainWindow.webContents.send('show-import-dialog');
        }
      },
      { type: 'separator' },
      {
        label: 'Quit BarqNet',
        click: () => {
          mainWindow.destroy();
          require('electron').app.quit();
        }
      }
    ]);

    tray.setContextMenu(contextMenu);
    tray.setToolTip(status.connected ? 'BarqNet - Connected' : 'BarqNet - Disconnected');
  };

  // Initial menu
  updateMenu();

  // Update menu when status changes
  vpnManager.on('status-changed', updateMenu);

  // Click tray icon to show window
  tray.on('click', () => {
    mainWindow.show();
    mainWindow.focus();
  });

  return tray;
}
