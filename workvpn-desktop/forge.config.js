module.exports = {
  packagerConfig: {
    name: 'BarqNet',
    executableName: 'barqnet',
    icon: './assets/icon',
    appBundleId: 'com.barqnet.desktop',
    appCategoryType: 'public.app-category.utilities',

    // macOS Code Signing (configure with environment variables)
    osxSign: process.env.APPLE_SIGNING_IDENTITY ? {
      identity: process.env.APPLE_SIGNING_IDENTITY,
      'hardened-runtime': true,
      entitlements: 'entitlements.plist',
      'entitlements-inherit': 'entitlements.plist',
      'signature-flags': 'library'
    } : undefined,

    // macOS Notarization (requires Apple Developer account)
    osxNotarize: process.env.APPLE_ID ? {
      appBundleId: 'com.barqnet.desktop',
      appleId: process.env.APPLE_ID,
      appleIdPassword: process.env.APPLE_ID_PASSWORD,
      teamId: process.env.APPLE_TEAM_ID
    } : undefined,

    // Windows metadata
    win32metadata: {
      CompanyName: 'BarqNet',
      ProductName: 'BarqNet Connect',
      FileDescription: 'BarqNet Desktop Client',
      OriginalFilename: 'BarqNet.exe'
    }
  },

  makers: [
    // Windows Squirrel installer
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'BarqNet',
        authors: 'BarqNet Team',
        description: 'Secure VPN client for Windows',
        iconUrl: 'https://barqnet.com/icon.ico', // TODO: Update with actual URL
        setupIcon: './assets/icon.ico',
        loadingGif: './assets/loading.gif' // Optional
      }
    },

    // macOS ZIP (for distribution)
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin']
    },

    // macOS DMG installer
    {
      name: '@electron-forge/maker-dmg',
      config: {
        format: 'ULFO',
        name: 'BarqNet',
        title: 'BarqNet Installer',
        background: './assets/dmg-background.png', // Optional
        icon: './assets/icon.icns',
        contents: [
          {
            x: 130,
            y: 220,
            type: 'file',
            path: process.platform === 'darwin' ?
              '/Applications/BarqNet.app' :
              './BarqNet.app'
          },
          {
            x: 410,
            y: 220,
            type: 'link',
            path: '/Applications'
          }
        ]
      }
    },

    // Linux DEB package
    {
      name: '@electron-forge/maker-deb',
      config: {
        options: {
          maintainer: 'BarqNet Team',
          homepage: 'https://barqnet.com',
          icon: './assets/icon.png',
          categories: ['Network', 'Security'],
          section: 'net'
        }
      }
    },

    // Linux RPM package (optional)
    {
      name: '@electron-forge/maker-rpm',
      config: {
        options: {
          license: 'MIT',
          homepage: 'https://barqnet.com'
        }
      }
    }
  ],

  publishers: [
    // GitHub Releases (optional)
    {
      name: '@electron-forge/publisher-github',
      config: {
        repository: {
          owner: 'your-org',
          name: 'barqnet-desktop'
        },
        prerelease: false,
        draft: true
      }
    }
  ]
};
