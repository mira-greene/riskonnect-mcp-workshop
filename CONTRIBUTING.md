# Contributing to Riskonnect MCP Workshop

Thank you for your interest in contributing to this workshop! This project helps Riskonnect partners learn how to integrate MCP servers with Salesforce Agentforce.

## Ways to Contribute

### 1. Report Issues

Found a bug or unclear instruction? [Open an issue](https://github.com/mira-greene/riskonnect-mcp-workshop/issues/new) with:
- **What happened:** Exact error message or symptom
- **Expected behavior:** What should have happened
- **Module:** Which module you were on (e.g., "Module 2, Checkpoint 2a")
- **Environment:** Salesforce CLI version, org type (scratch/dev/production)
- **Steps to reproduce:** Minimal steps to trigger the issue

### 2. Improve Documentation

Documentation PRs are always welcome:
- Fix typos or unclear instructions
- Add troubleshooting tips to `LESSONS-LEARNED.md`
- Improve code comments or script help text
- Add diagrams or screenshots

### 3. Enhance the Workshop

Ideas for enhancements:
- Additional MCP tools (e.g., `export_policy_to_pdf`, `generate_compliance_report`)
- Integration with real Riskonnect API (replace mock server)
- LWC components for Policy Gap visualization
- Flow automation for policy review workflows
- Multi-language support (translations of GUIDE.md)

### 4. Share Your Experience

Ran this workshop with your team? Share your experience:
- What worked well
- What was confusing
- How you adapted it for your audience
- Timing adjustments

Open a [discussion](https://github.com/mira-greene/riskonnect-mcp-workshop/discussions) to share feedback.

## Development Setup

```bash
git clone https://github.com/mira-greene/riskonnect-mcp-workshop.git
cd riskonnect-mcp-workshop
cp .env.example .env
# Edit .env with your test org alias
sf org login web --alias riskonnect-test
./scripts/01-check-env.sh
```

Test changes in a scratch org or dev sandbox before submitting a PR.

## Pull Request Process

1. **Fork** the repo and create a **feature branch**:
   ```bash
   git checkout -b feature/improve-module-2-docs
   ```

2. **Make your changes** and test them:
   - For documentation: read through the change as if you're a first-time participant
   - For code: deploy to a test org and verify the happy path still works
   - For scripts: run the affected scripts and check output

3. **Commit** with a clear message:
   ```bash
   git commit -m "Clarify External Credential Principal setup in Module 2"
   ```

4. **Push** to your fork:
   ```bash
   git push origin feature/improve-module-2-docs
   ```

5. **Open a Pull Request** with:
   - **Title:** Brief description (e.g., "Fix typo in GUIDE.md Module 3")
   - **Description:** What changed and why
   - **Testing:** How you verified the change works

## Code Style

### Bash Scripts
- Use `shellcheck` to lint scripts
- Follow existing naming conventions (`01-check-env.sh`, not `check_env.sh`)
- Use the `common.sh` helpers for consistency
- Add `--help` text for new scripts

### Salesforce Metadata
- Follow Salesforce DX naming conventions
- Use API version 62.0 or higher
- Test deployment in a fresh scratch org

### Documentation
- Use GitHub-flavored Markdown
- Keep lines under 100 characters (except code blocks)
- Use `🔴` emoji for critical checkpoints
- CLI commands should be in fenced code blocks with `bash` syntax highlighting

## Testing Checklist

Before submitting a PR that touches core workshop functionality:

- [ ] Deploy to a fresh scratch org succeeds
- [ ] Smoke test passes (3 tools returned)
- [ ] Agent activates without errors
- [ ] Conversation Preview returns real data
- [ ] Both CLI and UI tracks work (if you changed Module 2-4)
- [ ] Scripts have no shellcheck warnings
- [ ] Documentation has no broken links

## Questions?

Open a [discussion](https://github.com/mira-greene/riskonnect-mcp-workshop/discussions) or reach out to the maintainers.

## Code of Conduct

Be respectful, constructive, and collaborative. This is a learning resource — assume good intent, and help others learn.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
