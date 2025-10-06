# Testing .ovpn Import Feature

## Quick Test

1. **Launch the app** - You'll see the phone number entry screen
2. **Complete onboarding**:
   - Enter any phone number (e.g., +1 555 1234567)
   - Check console for OTP code (6 digits)
   - Enter OTP
   - Create password (min 8 chars)

3. **Import .ovpn file**:
   - After authentication, you'll see "No VPN Configuration" screen
   - Click **"IMPORT .OVPN FILE"** button
   - File dialog should open
   - Select an .ovpn file
   - If successful, you'll see the VPN status screen with connect button

## Sample .ovpn File

A sample `sample.ovpn` file is included in the project root for testing.

## Troubleshooting

### If the import button doesn't respond:
1. Open Developer Tools (View → Toggle Developer Tools)
2. Check the Console tab for error messages
3. Look for messages starting with `[Import]` or `[Main]`

### Common issues:

**Dialog doesn't open:**
- Check console for `[Main] Import config requested`
- Verify no error about "No main window available"

**Invalid config error:**
- Make sure the .ovpn file has a `remote` directive
- Format: `remote vpn.example.com 1194`

**No file selected:**
- If you cancel the dialog, this message is expected
- Try clicking Import again and select a file

### Expected Console Output

When clicking Import, you should see:
```
[Import] Opening file dialog...
[Main] Import config requested
[Main] Dialog result: { canceled: false, filePaths: [...] }
[Main] Importing config from: /path/to/file.ovpn
[Main] Config imported successfully
[Import] Result: { success: true }
[Import] Success! Loading config...
```

## Creating Your Own .ovpn File

Minimum required content:
```
client
dev tun
proto udp
remote your-vpn-server.com 1194

<ca>
[Certificate Authority certificate]
</ca>

<cert>
[Client certificate]
</cert>

<key>
[Private key]
</key>
```

Replace the certificates and keys with your actual VPN credentials.
