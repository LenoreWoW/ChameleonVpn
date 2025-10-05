import { BrowserWindow } from 'electron';
import path from 'path';

export function createMainWindow(): BrowserWindow {
  const mainWindow = new BrowserWindow({
    width: 500,
    height: 700,
    resizable: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, '../preload/index.js'),
    },
    titleBarStyle: 'hidden',
    title: 'WorkVPN',
    icon: path.join(__dirname, '../../assets/icon.png'),
  });

  // Load the renderer
  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  // Handle window close (minimize to tray)
  mainWindow.on('close', (event) => {
    if (!mainWindow.isDestroyed()) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  return mainWindow;
}
