## Catchup 2026-08-05 10:57 MDT

### Friction

Render Free does not expose a Rails shell or one-off job surface, so the approved temporary authenticated bridge was required for the console-only COV-47 operations. Render's masked environment editor did not provide reliable confirmation that the allowlist had been saved; the bridge status endpoint was the authoritative check.

### Mistakes

The initial recipient-allowlist save was treated as complete before the live bridge status confirmed it. The workflow should always wait for the staging restart and use the redacted status response before any mail-triggering operation. The first credentials-edit command also ran without the matching staging key; check for `config/credentials/staging.key` or a supplied `RAILS_MASTER_KEY` before launching the editor.

### Observations

The safe credential flow is to provide the existing staging key only as a transient `RAILS_MASTER_KEY` environment variable, edit through `VISUAL="zed --wait" mise exec -- bin/rails credentials:edit --environment staging`, keep the encrypted diff opaque, then deploy the exact commit. Specific-commit Render deployments require explicit restoration to linked `main` and auto-deploy during cleanup.
