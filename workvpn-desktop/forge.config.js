module.exports = {
  packagerConfig: {
    name: 'WorkVPN',
    executableName: 'workvpn',
    icon: './assets/icon',
    appBundleId: 'com.workvpn.desktop',
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
      appBundleId: 'com.workvpn.desktop',
      appleId: process.env.APPLE_ID,
      appleIdPassword: process.env.APPLE_ID_PASSWORD,
      teamId: process.env.APPLE_TEAM_ID
    } : undefined,

    // Windows metadata
    win32metadata: {
      CompanyName: 'WorkVPN',
      ProductName: 'WorkVPN Connect',
      FileDescription: 'WorkVPN Desktop Client',
      OriginalFilename: 'WorkVPN.exe'
    }
  },

  makers: [
    // Windows Squirrel installer
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'WorkVPN',
        authors: 'WorkVPN Team',
        description: 'Secure VPN client for Windows',
        iconUrl: 'https://workvpn.com/icon.ico', // TODO: Update with actual URL
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
        name: 'WorkVPN',
        title: 'WorkVPN Installer',
        background: './assets/dmg-background.png', // Optional
        icon: './assets/icon.icns',
        contents: [
          {
            x: 130,
            y: 220,
            type: 'file',
            path: process.platform === 'darwin' ?
              '/Applications/WorkVPN.app' :
              './WorkVPN.app'
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
          maintainer: 'WorkVPN Team',
          homepage: 'https://workvpn.com',
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
          homepage: 'https://workvpn.com'
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
          name: 'workvpn-desktop'
        },
        prerelease: false,
        draft: true
      }
    }
  ]
};
