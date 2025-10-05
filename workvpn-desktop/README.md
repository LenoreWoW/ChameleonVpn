# WorkVPN Desktop Client

A cross-platform desktop VPN client for Windows and macOS, built with Electron and OpenVPN.

## ✨ Features

- ✅ Import OpenVPN configuration files (.ovpn)
- ✅ Connect/disconnect VPN with one click
- ✅ System tray integration (macOS menu bar / Windows system tray)
- ✅ Real-time connection status with visual indicators
- ✅ Traffic statistics (Download/Upload tracking)
- ✅ Connection duration counter
- ✅ Auto-connect on startup
- ✅ Auto-start with system
- ✅ Kill switch support
- ✅ Encrypted config storage
- ✅ Multiple config management
- ✅ Beautiful gradient UI with animations

## 🚀 Quick Start

### Prerequisites

- **Node.js** 16 or higher
- **OpenVPN** installed on your system
  - **macOS**: `brew install openvpn`
  - **Windows**: Download from [openvpn.net](https://openvpn.net/community-downloads/)
- **Platform**: macOS 12+ or Windows 10/11

### Installation

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Start the app
npm start
```

### First Run

1. Launch WorkVPN
2. Click "Import .ovpn File"
3. Select your OpenVPN configuration file
4. Click "Connect" to establish VPN connection

## 📁 Project Structure

```
workvpn-desktop/
├── src/
│   ├── main/           # Main Electron process
│   │   ├── index.ts    # Application entry point
│   │   ├── window.ts   # Window management
│   │   ├── tray.ts     # System tray integration
│   │   ├── vpn/        # VPN connection logic
│   │   │   ├── manager.ts  # OpenVPN process management
│   │   │   └── parser.ts   # .ovpn file parser
│   │   └── store/      # Data persistence
│   │       └── config.ts   # Encrypted config storage
│   ├── preload/        # Preload scripts (IPC bridge)
│   │   └── index.ts
│   └── renderer/       # UI (Frontend)
│       ├── index.html
│       ├── styles.css
│       └── app.ts
├── assets/             # Icons and images
├── dist/              # Compiled JavaScript (generated)
├── out/               # Built applications (generated)
└── test-config.ovpn   # Sample config for testing
```

## 🛠️ Development

### Building

```bash
# Compile TypeScript and copy assets
npm run build

# Watch mode (auto-rebuild on changes)
npm run watch
```

### Running

```bash
# Development mode (with DevTools)
npm start

# Package for current platform
npm run package

# Create installer
npm run make
```

Output locations:
- **macOS**: `out/make/WorkVPN.dmg`
- **Windows**: `out/make/WorkVPN Setup.exe`

### Testing

See [SETUP_AND_TESTING.md](./SETUP_AND_TESTING.md) for comprehensive testing guide.

```bash
# Run integration tests
npm test
```

## 💻 Usage

### Importing a VPN Config

1. Launch WorkVPN
2. Click "Import .ovpn File" button
3. Select your OpenVPN configuration file
4. The config will be securely stored and encrypted

### Connecting to VPN

1. After importing a config, click "Connect"
2. The app will establish a secure VPN connection
3. Monitor connection status, IP, and traffic stats in real-time
4. Click "Disconnect" to terminate the connection

### System Tray Features

The system tray provides quick access to:
- **Connection Status**: 🟢 Connected / 🔴 Disconnected
- **Connect/Disconnect**: One-click VPN control
- **Show Window**: Bring main window to front
- **Import Config**: Quick config import
- **Quit**: Exit application

### Settings

Available in the main window:
- **Auto-connect on startup**: Automatically connect when app launches
- **Launch at system startup**: Start WorkVPN with your computer
- **Kill switch**: Block internet when VPN disconnects (security feature)

## 🏗️ Architecture

### Main Components

- **Main Process** (`src/main/`)
  - Manages VPN connections via OpenVPN child process
  - Handles system tray and window management
  - Manages file I/O and encrypted storage
  - IPC server for renderer communication

- **Renderer Process** (`src/renderer/`)
  - Beautiful gradient UI with state management
  - Real-time status updates and animations
  - Settings management interface

- **Preload Script** (`src/preload/`)
  - Secure bridge between main and renderer
  - Exposes safe IPC methods via contextBridge

### Security Features

- ✅ Context isolation enabled
- ✅ Node integration disabled in renderer
- ✅ Encrypted config storage (electron-store)
- ✅ Secure IPC communication
- ✅ Content Security Policy (CSP)

## 🔧 Built With

- **Electron** 28 - Cross-platform desktop framework
- **TypeScript** 5 - Type-safe JavaScript
- **OpenVPN** 2.6+ - VPN protocol implementation
- **electron-store** 8 - Encrypted persistent storage
- **electron-forge** 7 - Build and packaging

## 🌍 Platform Support

| Platform | Status | Installer | Tested |
|----------|--------|-----------|--------|
| macOS (Apple Silicon) | ✅ Ready | .dmg | ✅ M1/M2 |
| macOS (Intel) | ✅ Ready | .dmg | 🔄 Pending |
| Windows 10 | ✅ Ready | .exe | 🔄 Pending |
| Windows 11 | ✅ Ready | .exe | 🔄 Pending |

## 🐛 Troubleshooting

### macOS: "OpenVPN binary not found"
```bash
# Install OpenVPN via Homebrew
brew install openvpn

# Verify installation
which openvpn
# Should output: /opt/homebrew/sbin/openvpn
```

### Windows: "Permission denied"
Right-click the app and select "Run as Administrator"

### macOS: Permission issues
```bash
# Grant permissions to OpenVPN binary
sudo chmod +x /opt/homebrew/sbin/openvpn

# OR run app with elevated privileges
sudo npm start
```

### Connection fails
1. Verify your .ovpn config is valid (contains `remote` and `ca`)
2. Check if OpenVPN server is reachable
3. Review console logs for detailed error messages
4. Ensure firewall allows OpenVPN traffic

### Config import fails
1. Verify .ovpn file format (must contain `remote`, `ca`)
2. Check file encoding (must be UTF-8)
3. Look for syntax errors in the config

## 📊 Project Status

### Platform 1: Desktop (Electron) - In Progress

**Completed**:
- ✅ Electron project structure
- ✅ OpenVPN connection manager
- ✅ .ovpn config parser and validator
- ✅ System tray integration
- ✅ Main window UI with state management
- ✅ Encrypted config storage
- ✅ IPC communication (main ↔ renderer)
- ✅ Traffic statistics tracking
- ✅ Settings persistence
- ✅ macOS build configuration

**Pending**:
- 🔄 macOS 100% testing with real VPN server
- 🔄 Windows build and testing
- 🔄 Installer creation and distribution

**Next Platforms**:
- Platform 2: iOS app (NetworkExtension)
- Platform 3: Android app (ics-openvpn)

## 📖 Additional Documentation

- [SETUP_AND_TESTING.md](./SETUP_AND_TESTING.md) - Comprehensive testing guide
- [assets/README.md](./assets/README.md) - Icon generation guide

## 🔐 Security Notes

This is a **standard OpenVPN client** that:
- Works with any OpenVPN server
- Imports .ovpn configuration files
- Does NOT require custom backend API
- Stores configs encrypted locally
- Uses OS-level security features

## 📝 License

MIT License - see LICENSE for details

---

**Built with Electron + OpenVPN** 🔒
