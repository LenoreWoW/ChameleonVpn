# Technical Debt & Maintenance Notes

## OpenVPN Library Status

### Current Implementation
- **Library:** OpenVPNAdapter v0.8.0
- **Source:** https://github.com/ss-abramchuk/OpenVPNAdapter
- **Status:** ⚠️ Repository archived March 2022 (read-only, no longer maintained)
- **Last Assessment:** November 2025

### Why We're Keeping It

**Decision Date:** November 16, 2025

**Rationale:**
1. **Stable Foundation:** Based on OpenVPN 3 C++ core library which is stable and protocol-complete
2. **Production Ready:** Current implementation is professional, tested, and working perfectly
3. **Low Risk:**
   - OpenVPN protocol hasn't changed significantly
   - NetworkExtension API is stable since iOS 9
   - Library is a thin Objective-C wrapper around C++ core
   - Successfully tested on iOS 15-17

4. **Migration Cost vs Benefit:**
   - Alternative (OpenVPNXor) requires 6-10 hours of refactoring
   - OpenVPNXor has small community (18 GitHub stars)
   - Would be temporary solution before WireGuard anyway

### Risk Assessment

**Potential Risks:**
- ❌ No security updates for OpenVPNAdapter wrapper
- ❌ No iOS compatibility fixes if Apple breaks NetworkExtension
- ❌ No bug fixes from original maintainer

**Mitigation:**
- ✅ OpenVPN 3 C++ core is used by official OpenVPN Connect (actively maintained)
- ✅ NetworkExtension API has been stable for 10+ years
- ✅ Can fork and maintain ourselves if critical issues arise
- ✅ Planning WireGuard migration as long-term solution

**Probability of Issues:** LOW (< 10% over next 2 years)

### Monitoring Plan

**Quarterly Reviews:**
- Test on latest iOS version (currently iOS 17, soon iOS 18)
- Check for community forks or maintained alternatives
- Monitor Apple NetworkExtension API changes
- Evaluate WireGuard migration readiness

**Next Review Date:** February 2026

### Long-Term Strategy

**Timeline:**
- **Q1 2026:** Continue monitoring current implementation
- **Q2 2026:** Evaluate WireGuard migration feasibility
- **Q3 2026:** Begin WireGuard migration if justified
- **Q4 2026:** Complete migration to WireGuard (target)

### If Issues Arise

**Contingency Plans:**

1. **Option A - Fork OpenVPNAdapter:**
   - Fork repository to our organization
   - Update OpenVPN 3 submodule to latest
   - Maintain critical fixes ourselves
   - Effort: 2-3 hours initial + ongoing maintenance

2. **Option B - Migrate to OpenVPNXor:**
   - Use actively maintained alternative
   - Requires PacketTunnelProvider rewrite
   - Effort: 6-10 hours + testing

3. **Option C - Accelerate WireGuard Migration:**
   - Skip interim solutions
   - Jump directly to modern protocol
   - Effort: 15-20 hours + testing

### Technical Details

**Current Architecture:**
```
Swift (PacketTunnelProvider.swift)
    ↓
OpenVPNAdapter 0.8.0 (Objective-C wrapper)
    ↓
OpenVPN 3 C++ Core Library
    ↓
NetworkExtension Framework
```

**Key Files:**
- `/workvpn-ios/WorkVPNTunnelExtension/PacketTunnelProvider.swift`
- `/workvpn-ios/WorkVPN/Services/VPNManager.swift`
- `/workvpn-ios/Podfile` (lines 12, 18)

**Dependencies:**
- OpenVPNAdapter (from git, master branch)
- Commit: 33afba081c8592e8632128c7f9d6ebe53cae3d08

### References

- [OpenVPN 3 Core Library](https://github.com/OpenVPN/openvpn3) - Actively maintained
- [OpenVPN 3 Developer Guide](https://openvpn.github.io/openvpn3/)
- [OpenVPNAdapter Repository](https://github.com/ss-abramchuk/OpenVPNAdapter) - Archived
- [WireGuard iOS](https://git.zx2c4.com/wireguard-ios/) - Future migration target

---

**Document Owner:** Development Team
**Last Updated:** November 16, 2025
**Next Review:** February 2026
