# BarqNet Specialized Skills

**Version:** 1.0.0
**Created:** 2025-10-26
**Project:** BarqNet

---

## Overview

This directory contains **7 specialized AI agent skills** designed specifically for the BarqNet project. Each skill provides deep expertise in a specific domain, enabling efficient, high-quality development across all platforms and layers.

### What are Skills?

Skills are **reusable instruction sets** that Claude Code loads to provide specialized capabilities. Think of them as expert consultants - each one knows exactly how to handle specific types of tasks for your project.

---

## Available Skills

### 🔧 Development Skills

#### 1. **barqnet-backend** - Backend Development Agent
**Focus:** Go backend, PostgreSQL, API development, authentication

**Use When:**
- Implementing API endpoints
- Writing database migrations
- Handling authentication logic
- Working with JWT tokens
- Integrating OpenVPN server-side

**Key Expertise:**
- Go 1.19+, PostgreSQL 12+
- RESTful API design
- JWT authentication (HS256)
- Bcrypt password hashing
- SQL migration management

**Location:** `.claude/skills/barqnet-backend/`

---

#### 2. **barqnet-client** - Client Development Agent
**Focus:** Desktop/iOS/Android client applications

**Use When:**
- Building UI components
- Integrating OpenVPN client
- Implementing platform-specific features
- Managing secure storage
- Handling app lifecycle

**Key Expertise:**
- **Desktop:** Electron, TypeScript, React
- **iOS:** Swift, SwiftUI, NetworkExtension
- **Android:** Kotlin, Jetpack Compose, VpnService

**Platforms:**
- Desktop: `/Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-desktop/`
- iOS: `/Users/hassanalsahli/Desktop/ChameleonVpn/BarqNet/`
- Android: `/Users/hassanalsahli/Desktop/ChameleonVpn/BarqNetApp/`

**Location:** `.claude/skills/barqnet-client/`

---

#### 3. **barqnet-integration** - Integration Agent
**Focus:** Connecting clients to backend APIs

**Use When:**
- Implementing API contracts
- Setting up authentication flows
- Managing token lifecycle
- Handling network errors
- Testing cross-platform integration

**Key Expertise:**
- API contract design
- HTTP client implementation
- JWT token management
- Error handling strategies
- Cross-platform compatibility

**Location:** `.claude/skills/barqnet-integration/`

---

### 📝 Quality Assurance Skills

#### 4. **barqnet-documentation** - Documentation & Recording Agent
**Focus:** Creating and maintaining all project documentation

**Use When:**
- Writing API specifications
- Creating user guides
- Documenting architecture
- Recording changes
- Maintaining changelogs

**Key Expertise:**
- Technical writing
- API documentation
- Architecture diagrams
- Markdown formatting
- Documentation organization

**Location:** `.claude/skills/barqnet-documentation/`

---

#### 5. **barqnet-audit** - Code Audit Agent
**Focus:** Security, quality, and performance analysis

**Use When:**
- Reviewing code changes
- Conducting security audits
- Checking code quality
- Analyzing performance
- Pre-production reviews

**Key Expertise:**
- Security vulnerability detection
- Code quality assessment
- Performance analysis
- Best practices validation
- Architecture evaluation

**Location:** `.claude/skills/barqnet-audit/`

---

#### 6. **barqnet-testing** - Testing Agent
**Focus:** Comprehensive testing across all platforms

**Use When:**
- Writing unit tests
- Implementing integration tests
- Creating E2E test scenarios
- Setting up test automation
- Debugging test failures

**Key Expertise:**
- Unit testing (Go, Jest, XCTest, JUnit)
- Integration testing
- E2E testing (Playwright, UI tests)
- Test automation & CI/CD
- Performance testing

**Location:** `.claude/skills/barqnet-testing/`

---

### 🎯 Orchestration Skill

#### 7. **barqnet-e2e** - End-to-End Orchestrator Agent
**Focus:** Coordinating all agents for complete workflows

**Use When:**
- Implementing full-stack features
- Managing complex multi-platform tasks
- Coordinating production deployments
- Executing "ultrathink" workflows
- Need multiple agents working together

**Key Expertise:**
- Multi-agent coordination
- Task decomposition
- Dependency management
- Progress tracking
- Quality gate enforcement

**Location:** `.claude/skills/barqnet-e2e/`

---

## Quick Start

### Installation

Skills are already installed in your project at:
```
/Users/hassanalsahli/Desktop/ChameleonVpn/.claude/skills/
```

Claude Code will automatically detect and load them when referenced.

### Using Skills

#### Method 1: Explicit Skill Invocation (Recommended)

```
Use the barqnet-backend skill to add a new API endpoint for user profile management.
```

#### Method 2: Natural Language (Claude Auto-Detects)

```
I need to implement a new authentication endpoint on the backend.
```

Claude will recognize this requires `barqnet-backend` skill and activate it automatically.

#### Method 3: Multi-Skill Workflows

```
Use the barqnet-e2e skill to coordinate implementation of two-factor authentication across all platforms.
```

The E2E orchestrator will then deploy specialized agents as needed.

---

## Skill Selection Guide

### Decision Tree

```
Q: What are you working on?

├─ Backend API / Database
│  └─ Use: barqnet-backend

├─ Client Application (Desktop/iOS/Android)
│  └─ Use: barqnet-client

├─ Connecting Client to Backend
│  └─ Use: barqnet-integration

├─ Writing Documentation
│  └─ Use: barqnet-documentation

├─ Code Review / Security Audit
│  └─ Use: barqnet-audit

├─ Writing Tests
│  └─ Use: barqnet-testing

└─ Complex Multi-Platform Feature (affects 2+ areas)
   └─ Use: barqnet-e2e
```

### Use Case Matrix

| Task | Best Skill |
|------|-----------|
| Add new database table | barqnet-backend |
| Create new API endpoint | barqnet-backend |
| Implement UI screen | barqnet-client |
| Connect UI to API | barqnet-integration |
| Write API documentation | barqnet-documentation |
| Review security of auth flow | barqnet-audit |
| Write integration tests | barqnet-testing |
| Implement 2FA across all platforms | barqnet-e2e |
| Fix critical security bug | barqnet-e2e |
| Deploy to production | barqnet-e2e |

---

## Workflow Examples

### Example 1: Simple Backend Task

**Task:** Add endpoint to get user statistics

**Workflow:**
```
User: "Use barqnet-backend skill to add a GET /v1/user/stats endpoint that returns
       VPN usage statistics for the authenticated user."

Backend Agent:
1. Adds handler in apps/management/api/stats.go
2. Implements database query
3. Adds route in main.go
4. Writes unit tests
5. Documents in API_CONTRACT.md
```

**Skills Used:** 1 (barqnet-backend)

---

### Example 2: Cross-Platform Feature

**Task:** Implement server location selection

**Workflow:**
```
User: "Use barqnet-e2e skill to implement server location selection on all platforms."

E2E Orchestrator:
  Phase 1 - Backend (barqnet-backend):
    - Create locations table
    - Add GET /v1/vpn/locations endpoint
    - Populate with initial servers

  Phase 2 - Integration (barqnet-integration):
    - Define API contract
    - Specify location data format

  Phase 3 - Clients (barqnet-client):
    - Desktop: Server selector dropdown
    - iOS: Location picker UI
    - Android: Server selection screen

  Phase 4 - Documentation (barqnet-documentation):
    - API endpoint docs
    - User guide updates

  Phase 5 - Testing (barqnet-testing):
    - Integration tests
    - E2E tests on all platforms

  Phase 6 - Audit (barqnet-audit):
    - Security review
    - Code quality check
```

**Skills Used:** 6 (all except audit, orchestrated by E2E)

---

### Example 3: Production Deployment

**Task:** Deploy version 1.0 to production

**Workflow:**
```
User: "Use barqnet-e2e skill to prepare and execute production deployment."

E2E Orchestrator:
  Pre-Deploy:
    - barqnet-audit: Complete security and quality audit
    - barqnet-testing: Run full test suite
    - barqnet-documentation: Generate release notes

  Build:
    - barqnet-backend: Build backend binary
    - barqnet-client: Build all platform clients

  Deploy:
    - Database migrations
    - Backend deployment
    - Client distribution

  Post-Deploy:
    - barqnet-testing: Smoke tests
    - barqnet-documentation: Update deployment log
```

**Skills Used:** 5 (backend, client, documentation, testing, audit, orchestrated by E2E)

---

## Best Practices

### 1. Choose the Right Skill

✅ **DO:** Use specific skills for focused tasks
```
Use barqnet-backend to add JWT token expiry checking.
```

❌ **DON'T:** Use E2E for simple single-component tasks
```
Use barqnet-e2e to add a log statement. ❌
```

### 2. Let E2E Orchestrate Complex Work

✅ **DO:** Use E2E for multi-component features
```
Use barqnet-e2e to implement push notifications.
(Requires backend, all clients, testing, docs)
```

❌ **DON'T:** Try to manually coordinate agents yourself
```
First use backend, then integration, then client... ❌
(Let E2E orchestrator handle this)
```

### 3. Be Specific in Requests

✅ **DO:** Provide clear requirements
```
Use barqnet-client to add dark mode support to the Desktop app,
ensuring it persists user preference in electron-store.
```

❌ **DON'T:** Be vague
```
Use barqnet-client to make the app better. ❌
```

### 4. Trust the Specialization

Each skill has deep expertise in its domain. Let them:
- barqnet-backend: Handle all backend architecture decisions
- barqnet-client: Choose appropriate UI patterns
- barqnet-integration: Define optimal API contracts
- barqnet-documentation: Determine documentation structure
- barqnet-audit: Identify security issues
- barqnet-testing: Design test strategies
- barqnet-e2e: Coordinate multi-agent workflows

---

## Troubleshooting

### Issue: "Skill not found"

**Solution:** Skills should be at `.claude/skills/{skill-name}/SKILL.md`

Verify:
```bash
ls -la /Users/hassanalsahli/Desktop/ChameleonVpn/.claude/skills/
```

### Issue: "Wrong skill activated"

**Solution:** Be explicit in your request
```
Use the barqnet-backend skill to... [specific task]
```

### Issue: "Task requires multiple skills"

**Solution:** Use the E2E orchestrator
```
Use barqnet-e2e to [complex multi-component task]
```

---

## Skill Development Roadmap

### Current (v1.0.0)
- ✅ 7 core specialized skills
- ✅ E2E orchestration capability
- ✅ BarqNet-specific expertise

### Planned (v1.1.0)
- [ ] Performance optimization skill
- [ ] Database optimization skill
- [ ] DevOps/infrastructure skill

### Future (v2.0.0)
- [ ] AI-assisted debugging skill
- [ ] Automated refactoring skill
- [ ] Architecture evolution skill

---

## Contributing

### Adding New Skills

To add a new specialized skill:

1. Create directory: `.claude/skills/{skill-name}/`
2. Create `SKILL.md` with YAML frontmatter:
```yaml
---
name: skill-name
description: What this skill does and when to use it
---
```
3. Write skill instructions in Markdown
4. Update this README.md
5. Test with real tasks

### Improving Existing Skills

Skills can be enhanced by:
- Adding more examples
- Expanding reference documentation
- Including additional scripts/assets
- Updating for new platform versions

---

## Support

### Documentation
- Each skill: `.claude/skills/{skill-name}/SKILL.md`
- Project docs: `/Users/hassanalsahli/Desktop/ChameleonVpn/docs/`

### Getting Help
- Review skill's SKILL.md for detailed instructions
- Check examples in each skill
- Use E2E orchestrator for complex tasks

---

## Metrics

**Total Skills:** 7
**Lines of Skill Documentation:** ~20,000+
**Platforms Covered:** 4 (Backend, Desktop, iOS, Android)
**Languages Supported:** Go, TypeScript, Swift, Kotlin

---

**Last Updated:** 2025-10-26
**Version:** 1.0.0
**Status:** ✅ Production Ready
