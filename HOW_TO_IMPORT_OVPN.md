# 📱 How to Import .ovpn Files - Quick Guide

**For**: Backend developers and testers
**Platforms**: Android, iOS, Desktop
**Time**: 2 minutes per platform

---

## 🚀 QUICK START

### 1️⃣ Get a Sample .ovpn File

**Location**: `sample.ovpn` in project root

**Or create your own**:
```
client
dev tun
proto udp
remote vpn.your-server.com 1194

<ca>
-----BEGIN CERTIFICATE-----
[Your CA certificate]
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
[Your client certificate]
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
[Your private key]
-----END PRIVATE KEY-----
</key>
```

---

## 📱 ANDROID

### Step-by-Step

```
┌──────────────────────────────────────┐
│  1. Launch App                       │
│  2. Complete onboarding:             │
│     - Phone: +1 555 123 4567        │
│     - OTP: (check console)          │
│     - Password: (min 8 chars)       │
│                                      │
│  3. You'll see:                     │
│     ┌────────────────────────────┐ │
│     │   No VPN Configuration     │ │
│     │                            │ │
│     │   📄                       │ │
│     │                            │ │
│     │   Import an OpenVPN config │ │
│     │   file (.ovpn) to get      │ │
│     │   started                  │ │
│     │                            │ │
│     │  ┌──────────────────────┐ │ │
│     │  │ IMPORT .OVPN FILE    │ │ │
│     │  └──────────────────────┘ │ │
│     └────────────────────────────┘ │
│                                      │
│  4. Tap "IMPORT .OVPN FILE"         │
│  5. Android file picker opens       │
│  6. Navigate to your .ovpn file     │
│  7. Select it                       │
│  8. ✅ Success!                     │
└──────────────────────────────────────┘
```

### Transfer File to Android Device

**Method 1: ADB Push**
```bash
adb push sample.ovpn /sdcard/Download/sample.ovpn
```

**Method 2: Email**
1. Email yourself the .ovpn file
2. Open email on Android
3. Download attachment
4. Import from Downloads folder

**Method 3: Google Drive**
1. Upload to Google Drive on computer
2. Download from Drive app on Android
3. Import from Downloads folder

---

## 💻 DESKTOP (macOS, Windows, Linux)

### Step-by-Step

```
┌──────────────────────────────────────┐
│  1. Launch App                       │
│  2. Complete onboarding              │
│                                      │
│  3. Click "IMPORT .OVPN FILE"       │
│     ┌────────────────────────────┐ │
│     │                            │ │
│     │   🔒                       │ │
│     │                            │ │
│     │   No VPN Configuration     │ │
│     │                            │ │
│     │   Import an OpenVPN config │ │
│     │   file (.ovpn) to get      │ │
│     │   started                  │ │
│     │                            │ │
│     │  ┌──────────────────────┐ │ │
│     │  │ IMPORT .OVPN FILE    │ │ │
│     │  └──────────────────────┘ │ │
│     └────────────────────────────┘ │
│                                      │
│  4. Native file dialog opens        │
│     - Filters to .ovpn and .conf   │
│     - Shows only OpenVPN files     │
│                                      │
│  5. Select sample.ovpn              │
│  6. ✅ VPN screen appears!          │
└──────────────────────────────────────┘
```

### File Location

**Sample file**: `workvpn-desktop/sample.ovpn`

**Your own file**: Put anywhere, file dialog can access

---

## 🍎 iOS

### Step-by-Step

```
┌──────────────────────────────────────┐
│  1. Transfer file to iPhone:         │
│     - AirDrop from Mac               │
│     - iCloud Drive                   │
│     - Email attachment               │
│                                      │
│  2. Launch App                       │
│  3. Complete onboarding              │
│                                      │
│  4. Tap "Import Configuration"      │
│                                      │
│  5. Choose "Choose from Files"      │
│     ┌────────────────────────────┐ │
│     │   📄                       │ │
│     │                            │ │
│     │   Import Configuration     │ │
│     │                            │ │
│     │   Select an OpenVPN config │ │
│     │   file (.ovpn) from your   │ │
│     │   device                   │ │
│     │                            │ │
│     │  ┌──────────────────────┐ │ │
│     │  │ 📁 Choose from Files │ │ │
│     │  └──────────────────────┘ │ │
│     │  ┌──────────────────────┐ │ │
│     │  │ 📥 Import via AirDrop│ │ │
│     │  └──────────────────────┘ │ │
│     └────────────────────────────┘ │
│                                      │
│  6. iOS Files picker opens          │
│  7. Navigate to file location:      │
│     - iCloud Drive                  │
│     - On My iPhone                  │
│     - Downloads                     │
│                                      │
│  8. Select .ovpn file               │
│  9. ✅ VPN screen appears!          │
└──────────────────────────────────────┘
```

### Transfer Methods

**AirDrop (Fastest)**:
1. On Mac: Right-click sample.ovpn → Share → AirDrop
2. Select your iPhone
3. On iPhone: Accept file (saves to Files app)

**iCloud Drive**:
1. On Mac: Copy sample.ovpn to iCloud Drive folder
2. On iPhone: Open Files app → iCloud Drive
3. File will sync automatically

**Email**:
1. Email yourself sample.ovpn
2. Open email on iPhone
3. Tap attachment → Save to Files
4. Import from Files app

---

## ✅ SUCCESS INDICATORS

### After Successful Import

**You should see**:

```
┌────────────────────────────────────┐
│  WorkVPN          ⚙️ Settings      │
│                                    │
│          ●                         │
│      (green circle)                │
│                                    │
│      DISCONNECTED                  │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ Server: vpn.example.com      │ │
│  │ Protocol: UDP:1194           │ │
│  │ Duration: --                 │ │
│  └──────────────────────────────┘ │
│                                    │
│  ┌────────┐  ┌────────┐          │
│  │ ⬇️ 0 MB │  │ ⬆️ 0 MB │          │
│  └────────┘  └────────┘          │
│                                    │
│  ┌──────────────────────────────┐ │
│  │         CONNECT              │ │
│  └──────────────────────────────┘ │
│                                    │
│  Delete Configuration              │
└────────────────────────────────────┘
```

**Key info displayed**:
- ✅ Server address (from `remote` directive)
- ✅ Protocol and port (from `proto` and `remote`)
- ✅ Connect button enabled
- ✅ No error messages

---

## ❌ ERROR MESSAGES

### Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| **"Missing remote server address"** | No `remote` directive | Add `remote vpn.server.com 1194` |
| **"Missing CA certificate"** | No `<ca>` block | Add CA cert between `<ca>` and `</ca>` |
| **"Invalid port number"** | Port not 1-65535 | Use valid port (usually 1194) |
| **"Failed to import config"** | File not found | Check file location |
| **"No file selected"** | Cancelled dialog | Try again, select a file |

---

## 🧪 TESTING CHECKLIST

### Test Scenarios

- [ ] **Valid file**: Import sample.ovpn → Should succeed
- [ ] **Invalid file**: Import text file → Should show error
- [ ] **Missing remote**: Import .ovpn without server → Error message
- [ ] **Missing CA**: Import .ovpn without CA cert → Error message
- [ ] **Cancel dialog**: Open import, cancel → No crash, can retry
- [ ] **Large file**: Import 1MB+ .ovpn → Should handle gracefully
- [ ] **Multiple imports**: Import, delete, import again → Should work

---

## 🔧 TROUBLESHOOTING

### Android

**Problem**: Can't find .ovpn file in picker
**Solution**:
1. Make sure file is on device (check Downloads folder)
2. Try using different file manager
3. Use `adb push` to transfer directly

**Problem**: Import button doesn't respond
**Solution**:
1. Check app has storage permissions
2. Restart app
3. Check Android version (6.0+ required)

---

### Desktop

**Problem**: Import button grayed out
**Solution**:
1. Complete onboarding first
2. Make sure you're logged in
3. Restart app if stuck

**Problem**: File dialog doesn't show .ovpn files
**Solution**:
1. Check file extension is `.ovpn` (not `.txt`)
2. Select "All Files" in dialog filter dropdown
3. Make sure file isn't hidden

**Console Errors**:
- Open DevTools: `Cmd/Ctrl + Shift + I`
- Check Console tab
- Look for `[Import]` or `[Main]` messages
- Share errors for debugging

---

### iOS

**Problem**: Can't find file in Files app
**Solution**:
1. Make sure file was saved to Files app
2. Check "On My iPhone" location
3. Try iCloud Drive location
4. Re-transfer via AirDrop

**Problem**: "Import via AirDrop" shows "coming soon"
**Solution**:
- This feature is planned for future release
- Use "Choose from Files" instead (fully functional)

---

## 📊 VALIDATION REQUIREMENTS

### Your .ovpn File Must Have

**Required**:
- ✅ `remote <hostname> <port>` - Server address
- ✅ `<ca>` block with certificate - CA certificate

**Recommended**:
- 🟡 `dev tun` - Device type
- 🟡 `proto udp` or `proto tcp` - Protocol
- 🟡 `<cert>` block - Client certificate
- 🟡 `<key>` block - Private key
- 🟡 `cipher AES-256-CBC` - Encryption

**Optional**:
- ⚪ `<tls-auth>` - TLS authentication
- ⚪ `comp-lzo` - Compression
- ⚪ `auth SHA256` - HMAC digest

---

## 🎯 FOR BACKEND DEVELOPERS

### Option 1: Manual Import (Current)

Your colleague gives users a .ovpn file:
1. Generate .ovpn on server
2. Send to user (email, download link, etc.)
3. User imports via app

**Pros**: Simple, works now
**Cons**: Manual process

---

### Option 2: API Download (Future)

Add backend endpoint:
```
GET /api/vpn/config
Authorization: Bearer <token>

Response:
{
  "ovpnContent": "client\ndev tun\n...",
  "serverAddress": "vpn.server.com",
  "port": 1194,
  "protocol": "udp"
}
```

Then app can:
1. Call API after authentication
2. Receive .ovpn content
3. Parse and save automatically
4. No manual import needed!

**See**: `API_CONTRACT.md` for full spec

---

## 📚 RELATED DOCS

- **Detailed Analysis**: `OVPN_IMPORT_ANALYSIS.md` - Complete technical docs
- **Desktop Testing**: `workvpn-desktop/IMPORT_TESTING.md` - Desktop-specific guide
- **API Contract**: `API_CONTRACT.md` - Backend integration
- **Parser Tests**: `workvpn-android/app/src/test/.../OVPNParserTest.kt`

---

## ✨ SAMPLE FILES

| Location | Description |
|----------|-------------|
| `sample.ovpn` | Project root (all platforms) |
| `workvpn-desktop/sample.ovpn` | Desktop original |
| `workvpn-android/app/src/main/res/raw/sample.ovpn` | Android resources |
| `workvpn-ios/WorkVPN/Resources/sample.ovpn` | iOS resources |

---

## 🎉 YOU'RE READY!

**Next steps**:
1. ✅ Grab `sample.ovpn` from project root
2. ✅ Follow platform-specific guide above
3. ✅ Import file in app
4. ✅ See VPN configuration screen
5. ✅ Click Connect to test VPN

**Questions?**
- Check `OVPN_IMPORT_ANALYSIS.md` for deep dive
- Check `workvpn-desktop/IMPORT_TESTING.md` for Desktop troubleshooting
- Check console logs for error details

---

*Happy importing! 🚀*
*Last Updated: 2025-10-15*
