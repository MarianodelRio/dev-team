# Security Policy

## Supported versions

dev-team is a framework distributed as files copied into your project. There are no versioned releases with separate support windows — the `main` branch is always the supported version.

## Reporting a vulnerability

If you discover a security vulnerability in this framework, please report it privately rather than opening a public issue.

**Contact:** mariano.del.rio@accenture.com

Include in your report:
- A description of the vulnerability
- Steps to reproduce or a proof of concept
- The potential impact
- Any suggested fix if you have one

You will receive an acknowledgement within 48 hours. We aim to triage and respond with a remediation plan within 7 days.

## Scope

Vulnerabilities of interest include:
- Command injection in `install.sh` or any generated shell scripts
- Prompt injection patterns in agent definitions that could cause agents to exfiltrate data or execute unintended commands
- Insecure defaults in `devteam.config.yml` that expose secrets or credentials
- Weaknesses in the branch policy or task lifecycle that could allow unauthorized code to reach `main`

## Out of scope

- Vulnerabilities in Claude Code itself or the Anthropic API — report those to Anthropic
- Vulnerabilities in the user's project that happens to use dev-team
- Social engineering attacks

## Disclosure policy

We follow responsible disclosure. Once a fix is available, we will publish a brief advisory describing the issue and the fix. We credit reporters by name unless they request anonymity.
