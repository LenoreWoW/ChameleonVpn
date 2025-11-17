#!/bin/bash
#
# BarqNet Java 17 Installation Script
#
# This script automatically installs Java 17 (required for Android builds)
# and configures the environment variables permanently.
#
# Usage: ./install-java17.sh
#

set -e  # Exit on error

echo "========================================"
echo "BarqNet - Java 17 Installation"
echo "========================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo "ℹ️  $1"
}

# Check current Java version
echo "Step 1: Checking current Java version..."
if command -v java &> /dev/null; then
    CURRENT_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo "Current Java version: $CURRENT_VERSION"

    # Check if it's Java 17 or higher
    MAJOR_VERSION=$(echo $CURRENT_VERSION | cut -d'.' -f1)
    if [ "$MAJOR_VERSION" -ge 17 ]; then
        print_success "Java 17+ is already installed!"
        echo ""
        echo "Java Home: $JAVA_HOME"
        echo "Java Path: $(which java)"
        echo ""
        print_info "You're all set! Android builds should work."
        exit 0
    else
        print_warning "Java $CURRENT_VERSION detected - upgrading to Java 17..."
    fi
else
    print_info "No Java installation detected - installing Java 17..."
fi

echo ""

# Detect OS
echo "Step 2: Detecting operating system..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    print_info "Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    print_info "Detected: Linux"
else
    print_error "Unsupported operating system: $OSTYPE"
    echo "This script supports macOS and Linux only."
    echo "For Windows, please download Java 17 from: https://adoptium.net/temurin/releases/"
    exit 1
fi

echo ""

# Install Java 17
echo "Step 3: Installing Java 17..."

if [ "$OS" == "macOS" ]; then
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is not installed"
        echo "Please install Homebrew first: https://brew.sh"
        exit 1
    fi

    print_info "Installing OpenJDK 17 via Homebrew..."
    brew install openjdk@17

    JAVA_HOME_PATH="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

    # Check if the path exists, if not try alternative
    if [ ! -d "$JAVA_HOME_PATH" ]; then
        JAVA_HOME_PATH="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    fi

elif [ "$OS" == "Linux" ]; then
    print_info "Installing OpenJDK 17 via apt..."

    # Detect Linux distribution
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y openjdk-17-jdk
        JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
    elif command -v yum &> /dev/null; then
        sudo yum install -y java-17-openjdk-devel
        JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk"
    else
        print_error "Could not detect package manager (apt/yum)"
        exit 1
    fi
fi

print_success "Java 17 installed successfully!"
echo ""

# Configure JAVA_HOME
echo "Step 4: Configuring JAVA_HOME environment variable..."

# Detect shell configuration file
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
    SHELL_NAME="zsh"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_NAME="bash"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
    SHELL_NAME="bash"
else
    SHELL_CONFIG="$HOME/.profile"
    SHELL_NAME="shell"
fi

print_info "Using shell config: $SHELL_CONFIG"

# Check if JAVA_HOME is already configured
if grep -q "JAVA_HOME.*openjdk@17" "$SHELL_CONFIG" 2>/dev/null; then
    print_warning "JAVA_HOME already configured in $SHELL_CONFIG"
else
    print_info "Adding JAVA_HOME to $SHELL_CONFIG..."

    echo "" >> "$SHELL_CONFIG"
    echo "# Java 17 Configuration (added by BarqNet install script)" >> "$SHELL_CONFIG"
    echo "export JAVA_HOME=\"$JAVA_HOME_PATH\"" >> "$SHELL_CONFIG"
    echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$SHELL_CONFIG"

    print_success "JAVA_HOME configured in $SHELL_CONFIG"
fi

# Apply to current session
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

echo ""

# Verify installation
echo "Step 5: Verifying installation..."

if command -v java &> /dev/null; then
    NEW_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    MAJOR=$(echo $NEW_VERSION | cut -d'.' -f1)

    if [ "$MAJOR" -ge 17 ]; then
        print_success "Java 17+ verified!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Installation Complete!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Java Version: $NEW_VERSION"
        echo "JAVA_HOME:    $JAVA_HOME"
        echo "Java Path:    $(which java)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_info "To apply changes to your current terminal:"
        echo "  source $SHELL_CONFIG"
        echo ""
        print_info "Or simply open a new terminal window."
        echo ""
        print_success "You can now build Android!"
        echo ""
        echo "Next steps:"
        echo "  1. Reload your shell: source $SHELL_CONFIG"
        echo "  2. Navigate to Android: cd workvpn-android"
        echo "  3. Build the APK: ./gradlew assembleDebug"
        echo ""
    else
        print_error "Installation completed but Java version is still $NEW_VERSION"
        echo "Expected Java 17 or higher"
        exit 1
    fi
else
    print_error "Java installation failed - java command not found"
    exit 1
fi

print_success "All done! 🎉"
