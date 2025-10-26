# Contributing to BarqNet

Thank you for your interest in contributing to BarqNet! This document provides guidelines and instructions for contributing to this multi-platform VPN client project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Security](#security)
- [Questions](#questions)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Our Standards

**Positive behavior includes**:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Accepting constructive criticism gracefully
- Focusing on what is best for the project
- Showing empathy towards other contributors

**Unacceptable behavior includes**:
- Harassment, trolling, or derogatory comments
- Publishing others' private information
- Other conduct that could reasonably be considered inappropriate

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

#### For Android Development
- Android Studio Hedgehog (2023.1.1) or later
- JDK 17+
- Android SDK 34
- Git

#### For iOS Development
- macOS with Xcode 15.0+
- CocoaPods installed
- Apple Developer account (for device testing)
- Git

#### For Desktop Development
- Node.js 20+
- npm 10+
- OpenVPN installed (for testing)
- Git

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/barqnet.git
   cd barqnet
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/original/barqnet.git
   ```

---

## Development Setup

### Android Setup

```bash
cd barqnet-android

# Install dependencies (automatically via Gradle)
./gradlew build

# Run tests
./gradlew test

# Install on device
./gradlew installDebug
```

**See**: [barqnet-android/README.md](barqnet-android/README.md) for detailed setup

### iOS Setup

```bash
cd barqnet-ios

# Install dependencies
pod install

# Open in Xcode
open BarqNet.xcworkspace
```

**See**: [barqnet-ios/SETUP.md](barqnet-ios/SETUP.md) for detailed setup

### Desktop Setup

```bash
cd barqnet-desktop

# Install OpenVPN
brew install openvpn  # macOS
# OR: sudo apt install openvpn  # Linux
# OR: choco install openvpn      # Windows

# Install dependencies
npm install

# Run in development mode
npm start

# Run tests
npm test
```

**See**: [barqnet-desktop/SETUP.md](barqnet-desktop/SETUP.md) for detailed setup

---

## Project Structure

```
BarqNet/
├── barqnet-android/        # Android app (Kotlin + Compose)
│   ├── app/src/main/
│   ├── app/src/test/
│   └── build.gradle
│
├── barqnet-desktop/        # Desktop app (Electron + TypeScript)
│   ├── src/main/
│   ├── src/renderer/
│   ├── test/
│   └── package.json
│
├── barqnet-ios/            # iOS app (Swift + SwiftUI)
│   ├── BarqNet/
│   ├── BarqNetTunnelExtension/
│   ├── Tests/
│   └── Podfile
│
├── scripts/                # Build automation scripts
│   ├── build-all.sh
│   └── test-all.sh
│
├── .github/                # GitHub Actions workflows
│   ├── workflows/
│   └── dependabot.yml
│
└── docs/                   # Documentation
    ├── README.md
    ├── API_CONTRACT.md
    └── CONTRIBUTING.md (this file)
```

---

## Coding Standards

### General Principles

1. **Write clean, readable code** - Code is read more often than written
2. **Follow platform conventions** - Each platform has its own idioms
3. **Document complex logic** - Comments explain "why", not "what"
4. **Keep functions small** - Single Responsibility Principle
5. **Avoid premature optimization** - Readability first, optimize later
6. **Write tests** - All new features should include tests

### Platform-Specific Standards

#### Android (Kotlin)

**Style Guide**: Follow [Kotlin official style guide](https://kotlinlang.org/docs/coding-conventions.html)

**Code Style**:
```kotlin
// ✅ Good
class VPNManager(
    private val context: Context,
    private val config: VPNConfig
) {
    fun connect() {
        // Implementation
    }
}

// ❌ Bad
class VPNManager(private val context:Context,private val config:VPNConfig){
    fun connect(){
        //Implementation
    }
}
```

**Naming Conventions**:
- Classes: `PascalCase`
- Functions: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Private properties: `_camelCase` (if backing property)

**Tools**:
```bash
# Run ktlint
./gradlew ktlintCheck

# Auto-format
./gradlew ktlintFormat

# Run detekt (static analysis)
./gradlew detekt
```

#### iOS (Swift)

**Style Guide**: Follow [Swift official style guide](https://swift.org/documentation/api-design-guidelines/)

**Code Style**:
```swift
// ✅ Good
class VPNManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected

    func connect() {
        // Implementation
    }
}

// ❌ Bad
class VPNManager:ObservableObject{
    @Published var connectionState:ConnectionState = .disconnected
    func connect(){
        //Implementation
    }
}
```

**Naming Conventions**:
- Classes/Structs: `PascalCase`
- Functions/Variables: `camelCase`
- Enums: `PascalCase` (cases: `camelCase`)
- Constants: `camelCase`

**Tools**:
```bash
# Install SwiftLint
brew install swiftlint

# Run SwiftLint
swiftlint

# Auto-fix
swiftlint --fix
```

#### Desktop (TypeScript)

**Style Guide**: Follow [TypeScript guidelines](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)

**Code Style**:
```typescript
// ✅ Good
interface VPNConfig {
  serverAddress: string;
  port: number;
}

class VPNManager {
  private config: VPNConfig;

  constructor(config: VPNConfig) {
    this.config = config;
  }

  public connect(): Promise<void> {
    // Implementation
  }
}

// ❌ Bad
interface VPNConfig{serverAddress:string;port:number;}
class VPNManager{
  private config:VPNConfig;
  constructor(config:VPNConfig){this.config=config;}
  public connect():Promise<void>{
    //Implementation
  }
}
```

**Naming Conventions**:
- Classes/Interfaces: `PascalCase`
- Functions/Variables: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Private members: `camelCase` (no underscore prefix)

**Tools**:
```bash
# Run ESLint
npm run lint

# Auto-fix
npm run lint:fix

# Type check
npm run typecheck
```

---

## Testing Guidelines

### Android Testing

**Unit Tests** (JUnit):
```kotlin
import org.junit.Test
import org.junit.Assert.*

class AuthManagerTest {
    @Test
    fun `hashPassword should produce valid BCrypt hash`() {
        val authManager = AuthManager()
        val hash = authManager.hashPassword("password123")

        assertTrue(hash.startsWith("$2a$"))
        assertTrue(authManager.verifyPassword("password123", hash))
    }
}
```

**Run tests**:
```bash
./gradlew test
./gradlew connectedAndroidTest  # Instrumented tests
```

### iOS Testing

**Unit Tests** (XCTest):
```swift
import XCTest
@testable import BarqNet

class VPNManagerTests: XCTestCase {
    func testConnectShouldStartVPN() {
        let manager = VPNManager()

        XCTAssertEqual(manager.connectionState, .disconnected)

        manager.connect()

        XCTAssertEqual(manager.connectionState, .connecting)
    }
}
```

**Run tests**:
```bash
xcodebuild test \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Desktop Testing

**Unit Tests** (Jest):
```typescript
import { VPNManager } from '../main/vpn/manager';

describe('VPNManager', () => {
  it('should start VPN connection', async () => {
    const manager = new VPNManager();

    const result = await manager.connect();

    expect(result.status).toBe('connected');
  });
});
```

**Run tests**:
```bash
npm test
npm run test:integration
```

### Test Coverage

**Minimum requirements**:
- Android: 70% code coverage
- iOS: 70% code coverage
- Desktop: 80% code coverage

**Run coverage**:
```bash
# Android
./gradlew jacocoTestReport

# Desktop
npm run test:coverage
```

---

## Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting, no code change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, build, etc.)
- `ci`: CI/CD changes

### Scopes

- `android`: Android-specific changes
- `ios`: iOS-specific changes
- `desktop`: Desktop-specific changes
- `vpn`: VPN core functionality
- `auth`: Authentication
- `ui`: User interface
- `build`: Build system
- `deps`: Dependencies

### Examples

```bash
# Good commit messages
feat(android): add WireGuard VPN support
fix(ios): resolve certificate parsing issue
docs: update README with OpenVPN setup instructions
refactor(desktop): extract VPN manager into separate module
test(android): add unit tests for AuthManager
chore(deps): upgrade ics-openvpn to v0.7.47

# Bad commit messages
updated files
fix bug
Added new feature
WIP
```

### Commit Message Body

Provide additional context in the body (optional):

```
feat(android): add kill switch functionality

Implements VpnService lockdown mode to prevent traffic leaks
when VPN connection drops. Integrates with both OpenVPN and
WireGuard services.

Closes #42
```

---

## Pull Request Process

### Before Creating a PR

1. **Create a feature branch**:
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes** following coding standards

3. **Write/update tests** for your changes

4. **Run tests locally**:
   ```bash
   # Android
   cd barqnet-android && ./gradlew test

   # Desktop
   cd barqnet-desktop && npm test

   # iOS
   cd barqnet-ios && xcodebuild test ...
   ```

5. **Commit your changes** following commit convention

6. **Push to your fork**:
   ```bash
   git push origin feat/your-feature-name
   ```

### Creating a Pull Request

1. Go to the original repository on GitHub
2. Click "New Pull Request"
3. Select your fork and branch
4. Fill out the PR template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] All tests pass

## Screenshots (if applicable)
Add screenshots for UI changes

## Related Issues
Closes #issue_number
```

### PR Review Process

1. **Automated Checks**: CI/CD will run automatically
   - Build succeeds on all platforms
   - All tests pass
   - Linting passes
   - Security scan passes

2. **Code Review**: Maintainers will review your code
   - Code quality
   - Test coverage
   - Documentation
   - Security implications

3. **Feedback**: Address any requested changes

4. **Approval**: Once approved, your PR will be merged

### PR Guidelines

**DO**:
- ✅ Keep PRs focused and small (< 500 lines preferred)
- ✅ Write clear descriptions
- ✅ Include tests
- ✅ Update documentation
- ✅ Respond to feedback promptly

**DON'T**:
- ❌ Mix multiple unrelated changes
- ❌ Submit PRs without tests
- ❌ Ignore CI failures
- ❌ Force push after review has started
- ❌ Include commented-out code

---

## Security

### Reporting Security Vulnerabilities

**DO NOT** create public GitHub issues for security vulnerabilities.

Instead, please email: **security@barqnet.com** (or your configured contact)

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours.

### Security Guidelines

When contributing:

1. **Never commit secrets**:
   - API keys
   - Passwords
   - Private keys
   - Certificates

2. **Use environment variables** for configuration

3. **Validate all user input**

4. **Follow OWASP guidelines** for security best practices

5. **Keep dependencies updated**

---

## Branch Strategy

### Main Branches

- `main`: Production-ready code
- `develop`: Development branch (integration)

### Feature Branches

Create from `develop`:
```bash
git checkout develop
git pull upstream develop
git checkout -b feat/your-feature
```

### Branch Naming

- Features: `feat/description`
- Fixes: `fix/description`
- Docs: `docs/description`
- Chores: `chore/description`

Examples:
- `feat/wireguard-support`
- `fix/certificate-parsing`
- `docs/update-readme`
- `chore/upgrade-dependencies`

---

## Release Process

1. **Create release branch** from `develop`:
   ```bash
   git checkout -b release/v1.1.0
   ```

2. **Update version numbers**:
   - Android: `build.gradle` (`versionCode`, `versionName`)
   - iOS: Xcode project settings
   - Desktop: `package.json` (`version`)

3. **Update CHANGELOG.md** with release notes

4. **Create PR** to `main`

5. **After merge**, create Git tag:
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push upstream v1.1.0
   ```

6. **GitHub Actions** will automatically create release builds

---

## Development Workflow

### Typical Workflow

1. **Check for existing issues** or create a new one
2. **Discuss approach** (for major changes)
3. **Fork and clone** repository
4. **Create feature branch**
5. **Implement changes** with tests
6. **Run local tests and linting**
7. **Commit with conventional commits**
8. **Push to your fork**
9. **Create Pull Request**
10. **Address review feedback**
11. **Merge after approval**

### Example Session

```bash
# 1. Update your fork
git checkout develop
git pull upstream develop

# 2. Create feature branch
git checkout -b feat/add-server-list

# 3. Make changes
# ... edit files ...

# 4. Test changes
cd barqnet-android && ./gradlew test

# 5. Commit
git add .
git commit -m "feat(android): add server list screen

Implements server selection UI with search and favorites.
Includes unit tests for ServerListViewModel.

Closes #45"

# 6. Push
git push origin feat/add-server-list

# 7. Create PR on GitHub
```

---

## Questions & Support

### Getting Help

- **Documentation**: Check [README.md](README.md) first
- **Issues**: Search existing GitHub issues
- **Discussions**: Use GitHub Discussions for questions
- **Email**: contact@barqnet.com (for private inquiries)

### Resources

- **Android**: [barqnet-android/README.md](barqnet-android/README.md)
- **iOS**: [barqnet-ios/SETUP.md](barqnet-ios/SETUP.md)
- **Desktop**: [barqnet-desktop/SETUP.md](barqnet-desktop/SETUP.md)
- **API**: [API_CONTRACT.md](API_CONTRACT.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)

---

## Recognition

Contributors will be recognized in:
- `CHANGELOG.md` for each release
- GitHub Contributors page
- Project README (for significant contributions)

---

## License

By contributing to BarqNet, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).

---

Thank you for contributing to BarqNet! 🎉

Your efforts help make this project better for everyone.

---

**Last Updated**: 2025-10-15
**Project**: BarqNet Multi-Platform VPN Client
**Maintainers**: Hassan Alsahli
