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
  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  // Open DevTools in development mode only
  if (process.env.NODE_ENV !== 'production') {
    mainWindow.webContents.openDevTools();
  }

  // Log console messages from renderer to main process
  mainWindow.webContents.on('console-message', (_event, _level, message) => {
    console.log(`[Renderer] ${message}`);
  });

  // Handle window close (minimize to tray)
  mainWindow.on('close', (event) => {
    if (!mainWindow.isDestroyed()) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  return mainWindow;
}
