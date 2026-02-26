# Security Policy

## Reporting Security Issues

If you discover a security vulnerability, please **do not** open a public issue. Instead:

1. **Email** the maintainers with:
   - Description of the vulnerability
   - Steps to reproduce (if possible)
   - Potential impact
   - Any suggested fixes

2. **Allow time for response** — We'll acknowledge within 48 hours and work toward a fix

3. **Keep it confidential** — Don't disclose publicly until a patch is available

## Security Considerations

This skill handles user input and API communication. Keep these in mind:

### API Authentication

- **Store tokens securely** — Use SinusBot's built-in secret management, not in logs
- **Regenerate tokens regularly** — If you suspect compromise
- **Use HTTPS** — When connecting to OpenClaw gateway in production
- **Validate responses** — Always assume network responses could be tampered with

### Input Validation

This skill includes input sanitization:
- Control characters are stripped
- Message length is limited (4096 chars max)
- Empty messages after sanitization are rejected

However, always validate on the agent side as well.

### Rate Limiting

Rate limiting is enabled by default to prevent:
- Spam mentions triggering API calls
- Abuse of computational resources
- DDoS-like behavior from a single user

Configure `rateLimitMs` based on your needs (default: 2000ms).

### Message Logging

- Be aware that messages may be logged by SinusBot or OpenClaw
- Never send passwords, tokens, or sensitive data via TeamSpeak
- Configure log retention policies appropriately

### Deployment Best Practices

1. **Run in restricted network** — SinusBot should not be exposed to the internet
2. **Use strong authentication** — Require proper token/session validation
3. **Monitor API calls** — Watch for unusual patterns or errors
4. **Keep dependencies updated** — Regularly update SinusBot and Node.js
5. **Use secrets management** — Don't hardcode tokens in configuration

## Known Limitations

- **TeamSpeak message limit:** 1024 chars per message (chunking mitigates this)
- **No end-to-end encryption:** Messages are decrypted by the agent
- **Stateless:** Each request is independent; no persistent state per user
- **Rate limiting is client-side:** Determined by `clientUid` from TeamSpeak

## Questions?

Contact the maintainers if you have security concerns or questions about safe usage.

---

**Your security feedback helps us improve!** 🔒
