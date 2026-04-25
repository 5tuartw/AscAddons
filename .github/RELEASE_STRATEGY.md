# Release Strategy

This repository contains multiple addons with independent release tags and workflows.

## Branch Policy

- Develop features on short-lived branches: `feature/<addon>-<topic>`.
- Keep `main` as the release-ready branch.
- Merge by PR (or equivalent review flow), then tag from `main`.
- Avoid tagging from local unreviewed branches.

## Tag Conventions

Use addon-specific tags:

- `avh-v<version>` for AscensionVanityHelper
- `aps-v<version>` for AscensionPromptSquelcher
- `atm-v<version>` for AscensionTrinketManager
- `autocollect-v<version>` for AutoCollect
- `mestats-v<version>` for MEStats
- `questkeys-v<version>` for QuestKeys
- `extrabars-v<version>` for ExtraBarsAscension

Examples:

- `questkeys-v1.1.0`
- `aps-v1.0.1`
- `extrabars-v0.4.2`

## Minimal Release Checklist

1. Confirm addon folder builds/runs in-game (`/reload` smoke test).
2. Verify README command examples and install steps still match behavior.
3. Ensure workflow tag prefix matches the addon being released.
4. Create and push tag from `main`.
5. Confirm GitHub Action created the expected zip artifact name.
6. Spot-check release notes body and README link in the release entry.

## Safety Notes

- Legacy `addon_updater.py` is deprecated; use `addon_manager` for update checks.
- Do not mix repository reorganization moves with a release tag in the same commit.
- Keep release commits small and addon-scoped when possible.
- Addon-specific workflows prune older releases in the same tag family after publishing, so the Releases page keeps only the latest published release per addon.
