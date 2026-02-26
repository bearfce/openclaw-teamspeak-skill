# Contributing to openclaw-teamspeak-skill

Thanks for your interest in contributing! This document provides guidelines for submitting issues, code, and improvements.

## Code of Conduct

Be respectful and constructive. This is a friendly project for the community.

## Reporting Issues

When reporting a bug or requesting a feature:

1. **Check existing issues** — Avoid duplicates
2. **Be specific** — Include version info, OS, steps to reproduce
3. **Provide logs** — Attach relevant error messages or logs
4. **Suggest solutions** (optional) — Your ideas are welcome

**Issue title format:** `[BUG]` or `[FEATURE]` followed by a brief description

Example:
```
[BUG] Message chunking fails for emoji-heavy responses
[FEATURE] Add persistent rate limit storage across restarts
```

## Code Contributions

### Setup

```bash
git clone https://github.com/bearfce/openclaw-teamspeak-skill.git
cd openclaw-teamspeak-skill
git checkout -b fix/your-issue-name
```

### Code Standards

- **JavaScript:** Use `const`/`let` (not `var`), add JSDoc comments for functions
- **Bash:** Use shellcheck; avoid hardcoded paths
- **Testing:** Test your changes locally before submitting
- **Commits:** Write clear commit messages: `fix: message chunking` or `docs: clarify rate limiting`

### Submitting a PR

1. Push to your fork
2. Create a PR with a clear title and description
3. Reference any related issues: `Fixes #42`
4. Respond to feedback promptly
5. Keep commits clean and focused

Example PR description:
```
## What
Implement message chunking in the JS mention bridge script.

## Why
Currently, responses >1024 chars are truncated. Chunking matches the behavior
of sinusbot-chat.sh and provides better UX.

## How
- Split long messages into 1024-char chunks
- Add small delay between chunks to prevent rate limiting
- Update logs to show chunk count

Fixes #15
```

### Review Process

- At least one approval before merging
- All CI checks must pass (linting, basic checks)
- Tests or manual verification for features

## Documentation

When updating code, please update docs:

- **SKILL.md:** Command descriptions, configuration
- **README.md:** Setup, examples, troubleshooting
- **Code comments:** Especially for complex logic

## Questions?

Ask in the repo's issues or discussions. We're here to help!

---

**Thank you for contributing!** 🙏
