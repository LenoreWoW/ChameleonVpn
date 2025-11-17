# Fix Backend Go Dependencies

## Issue:
```
missing go.sum entry for module providing package github.com/go-redis/redis/v8
missing go.sum entry for module providing package github.com/golang-jwt/jwt/v5
missing go.sum entry for module providing package golang.org/x/crypto/bcrypt
```

## Solution:

Run this single command to fix ALL dependencies:

```bash
cd ~/ChameleonVpn/barqnet-backend
go mod tidy
```

This will:
- ✅ Download all missing dependencies
- ✅ Update go.sum with correct hashes
- ✅ Fix import errors

Then build should work:
```bash
go build -o management ./apps/management
go build -o vpn ./apps/vpn
go build -o end-node ./apps/end-node
```

## What `go mod tidy` Does:

1. Scans all `.go` files for imports
2. Downloads missing dependencies
3. Updates `go.mod` and `go.sum`
4. Removes unused dependencies

## Verify It Worked:

```bash
# Should build without errors:
go build -o management ./apps/management

# Should see:
# (no output = success!)
```

---

## If Still Having Issues:

### Check Go Version:
```bash
go version
# Should be: go version go1.21 or higher
```

### Manually Add Specific Dependencies:
```bash
go get github.com/go-redis/redis/v8
go get github.com/golang-jwt/jwt/v5
go get golang.org/x/crypto/bcrypt
go mod tidy
```

### Clean Module Cache:
```bash
go clean -modcache
go mod download
go mod tidy
```

---

**TL;DR:** Just run `go mod tidy` - it fixes everything!
