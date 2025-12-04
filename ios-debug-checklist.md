# iOS App Debugging Checklist

## If the app is hanging in debug mode:

### 1. Check Network Connectivity
```bash
# From your Mac, ping the management server
ping 192.168.10.217

# Test if management server is reachable
curl -v http://192.168.10.217:8080/health
```

Expected response:
```json
{"status":"healthy","timestamp":1234567890,"version":"1.0.0","serverID":"management-server"}
```

### 2. Check Xcode Console for Errors

Look for these patterns in Xcode console:
- `[APIClient] Base URL updated to:` - Should show your server IP
- Connection errors like "Could not connect to the server"
- Certificate pinning errors
- Timeout errors

### 3. Common Issues:

**Issue:** App hangs at launch
**Solution:** The app might be trying to auto-login or fetch data on startup
- Check if there are stored credentials causing auto-login attempts
- Clear app data (Delete and reinstall)

**Issue:** "Could not connect to server"
**Solution:** 
- Verify management server IP is correct (line 139 in APIClient.swift)
- Ensure server is running: `curl http://192.168.10.217:8080/health`
- Check firewall rules on server

**Issue:** Certificate pinning errors
**Solution:** 
- The app expects HTTPS in production but uses HTTP in debug
- Make sure you're in DEBUG mode (running from Xcode)

### 4. Test Management Server Endpoints

From your Mac terminal:

```bash
# Test health endpoint
curl http://192.168.10.217:8080/health

# Test API root
curl http://192.168.10.217:8080/api

# Test auth endpoint (should return error but not timeout)
curl -X POST http://192.168.10.217:8080/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

All should respond within 1-2 seconds (not hang).

### 5. Add Debug Logging

If still hanging, add this to your iOS app's AppDelegate or first view controller:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // Test API connectivity immediately
    print("🔍 Testing API connection...")
    let url = URL(string: "http://192.168.10.217:8080/health")!
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("❌ API Error: \(error)")
        } else if let data = data {
            print("✅ API Response: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }
    task.resume()
}
```

### 6. Check for Blocking Operations

The hang might be due to synchronous operations on the main thread.
Search your code for:
- `.wait()` calls
- Synchronous network requests
- Heavy operations in `viewDidLoad()` or `viewWillAppear()`

