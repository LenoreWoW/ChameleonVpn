#!/bin/bash
# BarqNet - Prerequisite Checker and Installer
# Automatically checks and installs all required dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🚀 BarqNet - Prerequisite Checker & Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Detected OS: ${OS}${NC}"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Track what needs to be installed
NEEDS_INSTALL=()

echo -e "${BLUE}[1/8]${NC} Checking Homebrew (macOS package manager)..."
if [[ "$OS" == "macos" ]]; then
    if command -v brew &> /dev/null; then
        BREW_VERSION=$(brew --version | head -n1)
        print_status 0 "Homebrew installed: $BREW_VERSION"
    else
        print_status 1 "Homebrew not found"
        NEEDS_INSTALL+=("homebrew")
    fi
else
    print_info "Skipping Homebrew (not on macOS)"
fi
echo ""

echo -e "${BLUE}[2/8]${NC} Checking PostgreSQL..."
if command -v psql &> /dev/null; then
    PSQL_VERSION=$(psql --version)
    print_status 0 "PostgreSQL installed: $PSQL_VERSION"

    # Check if PostgreSQL is running
    if [[ "$OS" == "macos" ]]; then
        if brew services list | grep postgresql | grep started &> /dev/null; then
            print_status 0 "PostgreSQL service is running"
        else
            print_warning "PostgreSQL is installed but not running"
            echo -e "  ${YELLOW}→${NC} Starting PostgreSQL..."
            brew services start postgresql@14 || brew services start postgresql
            print_status 0 "PostgreSQL started"
        fi
    elif [[ "$OS" == "linux" ]]; then
        if systemctl is-active --quiet postgresql; then
            print_status 0 "PostgreSQL service is running"
        else
            print_warning "PostgreSQL is installed but not running"
            echo -e "  ${YELLOW}→${NC} Starting PostgreSQL..."
            sudo systemctl start postgresql
            print_status 0 "PostgreSQL started"
        fi
    fi
else
    print_status 1 "PostgreSQL not found"
    NEEDS_INSTALL+=("postgresql")
fi
echo ""

echo -e "${BLUE}[3/8]${NC} Checking Go (Golang)..."
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    print_status 0 "Go installed: $GO_VERSION"

    # Check Go version (need 1.21+)
    GO_VERSION_NUM=$(go version | sed -E 's/.*go([0-9]+\.[0-9]+).*/\1/')
    GO_MAJOR=$(echo $GO_VERSION_NUM | cut -d. -f1)
    GO_MINOR=$(echo $GO_VERSION_NUM | cut -d. -f2)
    if [[ "$GO_MAJOR" -ge 1 ]] && [[ "$GO_MINOR" -ge 21 ]]; then
        print_status 0 "Go version is sufficient (1.21+)"
    else
        print_warning "Go version may be too old (need 1.21+), but 1.25 is fine"
    fi
else
    print_status 1 "Go not found"
    NEEDS_INSTALL+=("go")
fi
echo ""

echo -e "${BLUE}[4/8]${NC} Checking Node.js and npm..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_status 0 "Node.js installed: $NODE_VERSION"
else
    print_status 1 "Node.js not found"
    NEEDS_INSTALL+=("node")
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_status 0 "npm installed: v$NPM_VERSION"
else
    print_status 1 "npm not found"
    if [[ ! " ${NEEDS_INSTALL[@]} " =~ " node " ]]; then
        NEEDS_INSTALL+=("npm")
    fi
fi
echo ""

echo -e "${BLUE}[5/8]${NC} Checking CocoaPods (for iOS)..."
if [[ "$OS" == "macos" ]]; then
    if command -v pod &> /dev/null; then
        POD_VERSION=$(pod --version)
        print_status 0 "CocoaPods installed: v$POD_VERSION"
    else
        print_status 1 "CocoaPods not found"
        NEEDS_INSTALL+=("cocoapods")
    fi
else
    print_info "Skipping CocoaPods (not on macOS)"
fi
echo ""

echo -e "${BLUE}[6/8]${NC} Checking Xcode (for iOS)..."
if [[ "$OS" == "macos" ]]; then
    if command -v xcodebuild &> /dev/null; then
        XCODE_VERSION=$(xcodebuild -version | head -n1)
        print_status 0 "Xcode installed: $XCODE_VERSION"
    else
        print_warning "Xcode not found (required for iOS development)"
        print_info "Install from App Store: https://apps.apple.com/app/xcode/id497799835"
    fi
else
    print_info "Skipping Xcode (not on macOS)"
fi
echo ""

echo -e "${BLUE}[7/8]${NC} Checking Java (for Android)..."
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n1)
    print_status 0 "Java installed: $JAVA_VERSION"
else
    print_status 1 "Java not found"
    NEEDS_INSTALL+=("java")
fi
echo ""

echo -e "${BLUE}[8/8]${NC} Checking BarqNet Database..."
if command -v psql &> /dev/null; then
    if psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw barqnet; then
        print_status 0 "BarqNet database exists"
    else
        print_warning "BarqNet database not found"
        echo -e "  ${YELLOW}→${NC} Creating database..."
        createdb -U postgres barqnet 2>/dev/null || {
            print_warning "Could not create database automatically"
            print_info "You may need to create it manually: createdb -U postgres barqnet"
        }
        if psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw barqnet; then
            print_status 0 "Database created successfully"
        fi
    fi
fi
echo ""

# Check .env files
echo -e "${BLUE}[Extra]${NC} Checking .env files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check management .env
if [ -f "$SCRIPT_DIR/barqnet-backend/apps/management/.env" ]; then
    print_status 0 "Management .env file exists"
else
    print_warning "Management .env file missing"
    if [ -f "$SCRIPT_DIR/barqnet-backend/apps/management/.env.example" ]; then
        echo -e "  ${YELLOW}→${NC} Creating from .env.example..."
        cp "$SCRIPT_DIR/barqnet-backend/apps/management/.env.example" "$SCRIPT_DIR/barqnet-backend/apps/management/.env"
        print_status 0 "Created .env from template"
        print_warning "IMPORTANT: Edit .env and update the credentials!"
    fi
fi

# Check endnode .env
if [ -f "$SCRIPT_DIR/barqnet-backend/apps/endnode/.env" ]; then
    print_status 0 "Endnode .env file exists"
else
    print_warning "Endnode .env file missing (optional)"
    print_info "Create it when you need to run the endnode server"
fi
echo ""

# Install missing dependencies
if [ ${#NEEDS_INSTALL[@]} -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ All prerequisites are installed!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Start backend: cd barqnet-backend/apps/management && go run main.go"
    echo "  2. Test iOS: ./setup-ios.sh"
    echo "  3. Test Desktop: cd workvpn-desktop && npm start"
    exit 0
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  ⚠️  Missing Dependencies Detected${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The following need to be installed:"
for item in "${NEEDS_INSTALL[@]}"; do
    echo "  - $item"
done
echo ""

read -p "Do you want to install missing dependencies automatically? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Installation cancelled.${NC}"
    echo ""
    echo -e "${BLUE}Manual installation instructions:${NC}"

    if [[ "$OS" == "macos" ]]; then
        for item in "${NEEDS_INSTALL[@]}"; do
            case $item in
                homebrew)
                    echo "  Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    ;;
                postgresql)
                    echo "  PostgreSQL: brew install postgresql@14 && brew services start postgresql@14"
                    ;;
                go)
                    echo "  Go: brew install go"
                    ;;
                node)
                    echo "  Node.js: brew install node"
                    ;;
                cocoapods)
                    echo "  CocoaPods: sudo gem install cocoapods"
                    ;;
                java)
                    echo "  Java: brew install openjdk@17"
                    ;;
            esac
        done
    elif [[ "$OS" == "linux" ]]; then
        for item in "${NEEDS_INSTALL[@]}"; do
            case $item in
                postgresql)
                    echo "  PostgreSQL: sudo apt-get install postgresql postgresql-contrib"
                    ;;
                go)
                    echo "  Go: sudo apt-get install golang-go"
                    ;;
                node)
                    echo "  Node.js: sudo apt-get install nodejs npm"
                    ;;
                java)
                    echo "  Java: sudo apt-get install openjdk-17-jdk"
                    ;;
            esac
        done
    fi
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📦 Installing Missing Dependencies...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$OS" == "macos" ]]; then
    # Install Homebrew first if needed
    if [[ " ${NEEDS_INSTALL[@]} " =~ " homebrew " ]]; then
        echo -e "${BLUE}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_status 0 "Homebrew installed"
        echo ""
    fi

    # Install PostgreSQL
    if [[ " ${NEEDS_INSTALL[@]} " =~ " postgresql " ]]; then
        echo -e "${BLUE}Installing PostgreSQL...${NC}"
        brew install postgresql@14
        brew services start postgresql@14
        print_status 0 "PostgreSQL installed and started"
        echo ""

        # Wait for PostgreSQL to start
        sleep 3

        # Create database
        echo -e "${BLUE}Creating BarqNet database...${NC}"
        createdb -U $(whoami) barqnet 2>/dev/null || createdb barqnet
        print_status 0 "Database created"
        echo ""
    fi

    # Install Go
    if [[ " ${NEEDS_INSTALL[@]} " =~ " go " ]]; then
        echo -e "${BLUE}Installing Go...${NC}"
        brew install go
        print_status 0 "Go installed"
        echo ""
    fi

    # Install Node.js
    if [[ " ${NEEDS_INSTALL[@]} " =~ " node " ]]; then
        echo -e "${BLUE}Installing Node.js...${NC}"
        brew install node
        print_status 0 "Node.js installed"
        echo ""
    fi

    # Install CocoaPods
    if [[ " ${NEEDS_INSTALL[@]} " =~ " cocoapods " ]]; then
        echo -e "${BLUE}Installing CocoaPods...${NC}"
        sudo gem install cocoapods
        print_status 0 "CocoaPods installed"
        echo ""
    fi

    # Install Java
    if [[ " ${NEEDS_INSTALL[@]} " =~ " java " ]]; then
        echo -e "${BLUE}Installing Java...${NC}"
        brew install openjdk@17
        print_status 0 "Java installed"
        echo ""
    fi

elif [[ "$OS" == "linux" ]]; then
    # Update package list
    echo -e "${BLUE}Updating package list...${NC}"
    sudo apt-get update
    echo ""

    # Install PostgreSQL
    if [[ " ${NEEDS_INSTALL[@]} " =~ " postgresql " ]]; then
        echo -e "${BLUE}Installing PostgreSQL...${NC}"
        sudo apt-get install -y postgresql postgresql-contrib
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        print_status 0 "PostgreSQL installed and started"
        echo ""

        # Wait for PostgreSQL to start
        sleep 3

        # Create database
        echo -e "${BLUE}Creating BarqNet database...${NC}"
        sudo -u postgres createdb barqnet 2>/dev/null || true
        print_status 0 "Database created"
        echo ""
    fi

    # Install Go
    if [[ " ${NEEDS_INSTALL[@]} " =~ " go " ]]; then
        echo -e "${BLUE}Installing Go...${NC}"
        sudo apt-get install -y golang-go
        print_status 0 "Go installed"
        echo ""
    fi

    # Install Node.js
    if [[ " ${NEEDS_INSTALL[@]} " =~ " node " ]]; then
        echo -e "${BLUE}Installing Node.js...${NC}"
        sudo apt-get install -y nodejs npm
        print_status 0 "Node.js installed"
        echo ""
    fi

    # Install Java
    if [[ " ${NEEDS_INSTALL[@]} " =~ " java " ]]; then
        echo -e "${BLUE}Installing Java...${NC}"
        sudo apt-get install -y openjdk-17-jdk
        print_status 0 "Java installed"
        echo ""
    fi
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Start backend: cd barqnet-backend/apps/management && go run main.go"
echo "  2. Test iOS: ./setup-ios.sh"
echo "  3. Test Desktop: cd workvpn-desktop && npm start"
echo ""
echo -e "${YELLOW}Note:${NC} You may need to restart your terminal for some changes to take effect."
echo ""
