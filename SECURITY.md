# Security Policy

## Supported Versions

Security fixes are applied to the latest released minor version on the `main`
branch. Older versions are not maintained — please upgrade to the latest release
before reporting an issue.

| Version | Supported |
| ------- | --------- |
| Latest `main` | ✅ |
| Older releases | ❌ |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
discussions, or pull requests.**

`AuthSessionKit` handles authentication sessions and biometric gating, so we
take security reports seriously. If you believe you have found a security
vulnerability, report it privately:

- **Email:** [92spatter.prose@icloud.com](mailto:92spatter.prose@icloud.com)
- Alternatively, use GitHub's [private vulnerability reporting][gh-advisory]
  on the repository (Security → Report a vulnerability), if enabled.

[gh-advisory]: https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability

### What to include

To help us triage quickly, please include as much of the following as you can:

- A description of the vulnerability and its impact.
- The affected product (`AuthSession` or `AuthSessionInterface`), file, and
  symbol if known.
- Steps to reproduce, or a minimal proof of concept.
- The version / commit you tested against.
- Any suggested remediation.

### What to expect

- **Acknowledgement** within **72 hours** of your report.
- An initial assessment and severity classification within **7 days**.
- Regular updates on remediation progress.
- Credit in the release notes and `CHANGELOG.md` once a fix ships, unless you
  prefer to remain anonymous.

### Disclosure policy

We follow a coordinated disclosure process. We ask that you give us a reasonable
window to release a fix before any public disclosure. We will work with you to
agree on a disclosure timeline appropriate to the severity of the issue.

## Scope

In scope:

- Logic flaws in session validation, expiry handling, or biometric gating.
- Concurrency issues that could leak or corrupt session state.
- Any path that could expose, persist, or transmit credentials insecurely.

Out of scope:

- Vulnerabilities in your own `AuthSessionProviderProtocol` conformer or backend.
- Vulnerabilities in third-party dependencies (report those upstream).
- Issues that require a jailbroken / compromised device or physical access.

Thank you for helping keep `AuthSessionKit` and its users safe.
