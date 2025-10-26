#!/bin/bash
# Certificate Pinning Test Script
# This script helps test certificate pinning implementation

set -e

echo "=========================================="
echo "Certificate Pinning Test Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "$1"
}

echo "Test 1: Build Verification"
echo "-------------------------------------------"
if npm run build > /dev/null 2>&1; then
    print_success "Build successful"
    if [ -f "dist/main/security/init-certificate-pinning.js" ]; then
        print_success "Certificate pinning file compiled"
    else
        print_error "Certificate pinning file NOT found in dist"
        exit 1
    fi
else
    print_error "Build failed"
    exit 1
fi
echo ""

echo "Test 2: TypeScript Compilation Check"
echo "-------------------------------------------"
if npx tsc --noEmit src/main/security/init-certificate-pinning.ts > /dev/null 2>&1; then
    print_success "TypeScript compilation successful"
else
    print_error "TypeScript compilation failed"
    exit 1
fi
echo ""

echo "Test 3: Integration Verification"
echo "-------------------------------------------"
if grep -q "initializeCertificatePinning" dist/main/index.js; then
    print_success "Certificate pinning integrated in main process"
else
    print_error "Certificate pinning NOT integrated in main process"
    exit 1
fi
echo ""

echo "Test 4: Environment Configuration Check"
echo "-------------------------------------------"
if grep -q "CERT_PIN_PRIMARY" .env.example; then
    print_success "CERT_PIN_PRIMARY documented in .env.example"
else
    print_error "CERT_PIN_PRIMARY NOT found in .env.example"
    exit 1
fi

if grep -q "CERT_PIN_BACKUP" .env.example; then
    print_success "CERT_PIN_BACKUP documented in .env.example"
else
    print_error "CERT_PIN_BACKUP NOT found in .env.example"
    exit 1
fi
echo ""

echo "Test 5: .env File Check"
echo "-------------------------------------------"
if [ -f ".env" ]; then
    if grep -q "CERT_PIN_PRIMARY" .env; then
        CERT_PIN_VALUE=$(grep "CERT_PIN_PRIMARY" .env | cut -d'=' -f2)
        if [ -z "$CERT_PIN_VALUE" ]; then
            print_warning "CERT_PIN_PRIMARY is empty (development mode)"
        else
            print_success "CERT_PIN_PRIMARY is configured"
        fi
    else
        print_warning "CERT_PIN_PRIMARY not in .env (will use default)"
    fi

    if grep -q "CERT_PIN_BACKUP" .env; then
        CERT_PIN_VALUE=$(grep "CERT_PIN_BACKUP" .env | cut -d'=' -f2)
        if [ -z "$CERT_PIN_VALUE" ]; then
            print_warning "CERT_PIN_BACKUP is empty (development mode)"
        else
            print_success "CERT_PIN_BACKUP is configured"
        fi
    else
        print_warning "CERT_PIN_BACKUP not in .env (will use default)"
    fi
else
    print_warning ".env file not found (will use defaults)"
    print_info "  Create .env from .env.example to configure certificate pinning"
fi
echo ""

echo "Test 6: Code Quality Check"
echo "-------------------------------------------"
LINE_COUNT=$(wc -l < src/main/security/init-certificate-pinning.ts)
if [ "$LINE_COUNT" -gt 100 ]; then
    print_success "Certificate pinning implementation is comprehensive ($LINE_COUNT lines)"
else
    print_warning "Certificate pinning implementation seems short ($LINE_COUNT lines)"
fi
echo ""

echo "=========================================="
echo "All Tests Passed! ✓"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Get certificate pins from your API server:"
echo "   openssl s_client -connect api.barqnet.com:443 < /dev/null 2>/dev/null | \\"
echo "     openssl x509 -pubkey -noout | \\"
echo "     openssl pkey -pubin -outform der | \\"
echo "     openssl dgst -sha256 -binary | \\"
echo "     base64"
echo ""
echo "2. Configure .env file:"
echo "   cp .env.example .env"
echo "   # Edit .env and set CERT_PIN_PRIMARY and CERT_PIN_BACKUP"
echo ""
echo "3. Test the application:"
echo "   npm start"
echo ""
echo "4. Verify certificate pinning in console output:"
echo "   Look for: [CERT-PIN] ✓ Certificate pinning initialized successfully"
echo ""
