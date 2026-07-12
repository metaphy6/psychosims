# Security policy

## Trust boundary

Psychosims is server-authoritative: any value computed by the client is treated
as a claim, not a fact. The server validates every receipt, ownership transfer,
and economy mutation.

## Threat model (stub)

- **Client tampering:** a modified client cannot forge valid receipts because
  receipt validation runs server-side against a pinned `ruleset_version`.
- **Secret leakage:** secrets are referenced by name in the repo and injected at
  runtime. CI and pre-commit hooks scan for accidental commits.
- **Model supply chain:** the ~1.8 GB GGUF model is fetched out-of-band and
  checksum-verified before load.
- **Prompt injection:** card-only input closes the direct channel; peer history
  and UGC manifests are treated as untrusted and sanitized at signing time.
- **No durable transcripts:** raw dialogue is never persisted server-side or in
  durable client storage.

## Responsible disclosure

Report security issues to the maintainer privately. Do not open public issues
for undisclosed vulnerabilities.

## Dependency scanning

Run `scripts/sbom.sh` to generate an SBOM and `scripts/vuln_check.sh` for a
vulnerability scan.
