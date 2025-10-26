# BarqNet Skills - Quick Reference Card

**Version:** 1.0.0 | **Date:** 2025-10-26

---

## Skill Selector

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHAMELEONVPN SKILLS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔧 DEVELOPMENT                                                 │
│  ├─ barqnet-backend      → Go, PostgreSQL, API               │
│  ├─ barqnet-client       → Desktop, iOS, Android             │
│  └─ barqnet-integration  → API contracts, auth flows         │
│                                                                 │
│  📝 QUALITY ASSURANCE                                           │
│  ├─ barqnet-documentation → Docs, specs, guides              │
│  ├─ barqnet-audit        → Security, quality, performance    │
│  └─ barqnet-testing      → Unit, integration, E2E tests      │
│                                                                 │
│  🎯 ORCHESTRATION                                               │
│  └─ barqnet-e2e          → Coordinates all agents            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## When to Use Each Skill

| Need to... | Use Skill |
|------------|-----------|
| Add API endpoint | `barqnet-backend` |
| Update database schema | `barqnet-backend` |
| Implement JWT auth | `barqnet-backend` |
| Build UI screen | `barqnet-client` |
| Add OpenVPN feature | `barqnet-client` |
| Connect UI to API | `barqnet-integration` |
| Handle token refresh | `barqnet-integration` |
| Write API docs | `barqnet-documentation` |
| Create user guide | `barqnet-documentation` |
| Security review | `barqnet-audit` |
| Code quality check | `barqnet-audit` |
| Write unit tests | `barqnet-testing` |
| Create E2E tests | `barqnet-testing` |
| Multi-platform feature | `barqnet-e2e` |
| Production deploy | `barqnet-e2e` |

---

## Usage Examples

### Simple Task (1 skill)
```
Use barqnet-backend to add GET /v1/user/profile endpoint.
```

### Medium Task (2-3 skills, let E2E coordinate)
```
Use barqnet-e2e to implement password reset functionality.
```

### Complex Task (4+ skills, ultrathink)
```
Use barqnet-e2e to implement subscription billing across all platforms.
```

---

## Skill Capabilities

### barqnet-backend
**Tech Stack:** Go, PostgreSQL, JWT
**Locations:** `/Users/hassanalsahli/Desktop/go-hello-main/`
**Handles:**
- API endpoints (auth, VPN, admin)
- Database migrations
- JWT token generation/validation
- OpenVPN server integration
- Bcrypt password hashing

**Quick Commands:**
```bash
go test ./...              # Run tests
go build ./apps/management # Build
golangci-lint run          # Lint
```

---

### barqnet-client
**Tech Stacks:**
- Desktop: Electron, TypeScript, React
- iOS: Swift, SwiftUI
- Android: Kotlin, Compose

**Locations:**
- `/Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-desktop/`
- `/Users/hassanalsahli/Desktop/ChameleonVpn/BarqNet/`
- `/Users/hassanalsahli/Desktop/ChameleonVpn/BarqNetApp/`

**Handles:**
- UI/UX implementation
- OpenVPN client integration
- Secure token storage
- Platform-specific features

**Quick Commands:**
```bash
# Desktop
npm run dev
npm test

# iOS
xcodebuild test -scheme BarqNet

# Android
./gradlew test
```

---

### barqnet-integration
**Expertise:** API contracts, HTTP clients, auth flows

**Handles:**
- Client-backend API integration
- JWT token management
- Request/response formatting
- Error handling strategies
- Cross-platform compatibility

**API Endpoints Managed:**
- `POST /v1/auth/send-otp`
- `POST /v1/auth/register`
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/vpn/status`
- `GET /v1/vpn/locations`

---

### barqnet-documentation
**Output Formats:** Markdown, API specs, diagrams

**Handles:**
- API documentation (OpenAPI/Swagger)
- User guides and manuals
- Architecture diagrams
- Changelog maintenance
- Troubleshooting guides

**Key Documents:**
- `API_CONTRACT.md`
- `ARCHITECTURE.md`
- `DEPLOYMENT_GUIDE.md`
- `CHANGELOG.md`
- `README.md`

---

### barqnet-audit
**Focus Areas:** Security, quality, performance

**Checks:**
- SQL injection vulnerabilities
- XSS vulnerabilities
- Authentication flaws
- Password hashing strength
- Token security
- Input validation
- Error handling
- Code quality
- Performance bottlenecks

**Tools Used:**
- Go: `go vet`, `golangci-lint`, `gosec`
- Desktop: `npm audit`, `tsc --noEmit`
- iOS: `swiftlint`, Instruments
- Android: `./gradlew lint`, detekt

---

### barqnet-testing
**Test Types:** Unit, Integration, E2E, Performance

**Frameworks:**
- Go: `testing` package
- Desktop: Jest, Playwright
- iOS: XCTest
- Android: JUnit, Espresso

**Coverage Targets:**
- Unit tests: 80%
- Critical paths: 100% (auth, security)

**Quick Commands:**
```bash
# Backend
go test -cover ./...

# Desktop
npm test -- --coverage

# iOS
xcodebuild test -enableCodeCoverage YES

# Android
./gradlew jacocoTestReport
```

---

### barqnet-e2e
**Role:** Multi-agent orchestrator

**Coordinates:**
1. Task analysis & decomposition
2. Agent selection & deployment
3. Dependency management
4. Progress tracking
5. Quality gate enforcement
6. Final integration & reporting

**Use For:**
- Features spanning 2+ platforms
- Production deployments
- Complex integrations
- UltraThink workflows

---

## Common Workflows

### Workflow 1: New API Endpoint
```
barqnet-backend:
  1. Add handler function
  2. Add route in main.go
  3. Write unit tests
  4. Update API_CONTRACT.md
```

### Workflow 2: New UI Feature
```
barqnet-client:
  1. Implement UI (Desktop/iOS/Android)
  2. Connect to backend API
  3. Handle loading/error states
  4. Write UI tests
```

### Workflow 3: Full-Stack Feature
```
barqnet-e2e orchestrates:
  1. barqnet-backend: API implementation
  2. barqnet-integration: API contract
  3. barqnet-client: UI on all platforms
  4. barqnet-testing: Integration tests
  5. barqnet-documentation: User guide
  6. barqnet-audit: Security review
```

---

## Troubleshooting

### Skill Not Activating?
Be explicit: `Use barqnet-backend to...`

### Need Multiple Skills?
Use E2E: `Use barqnet-e2e to...`

### Task Not Clear?
E2E will analyze and ask questions

---

## Quick Tips

1. **Single-platform task** → Use specific skill
2. **Multi-platform task** → Use `barqnet-e2e`
3. **Not sure which skill** → Use `barqnet-e2e` (it will delegate)
4. **Just documentation** → Use `barqnet-documentation`
5. **Just tests** → Use `barqnet-testing`
6. **Code review** → Use `barqnet-audit`

---

## File Structure

```
.claude/skills/
├── README.md                    ← Overview
├── QUICK_REFERENCE.md           ← This file
├── barqnet-backend/
│   └── SKILL.md
├── barqnet-client/
│   └── SKILL.md
├── barqnet-integration/
│   └── SKILL.md
├── barqnet-documentation/
│   └── SKILL.md
├── barqnet-audit/
│   └── SKILL.md
├── barqnet-testing/
│   └── SKILL.md
└── barqnet-e2e/
    └── SKILL.md
```

---

## Need Help?

1. Check skill's `SKILL.md` for detailed documentation
2. Review examples in skill file
3. Use `barqnet-e2e` for complex tasks
4. Refer to main project docs in `/docs/`

---

**Print this card or bookmark it for quick reference!**
