# Addons Reorganization Plan (Executed)

Goal: make first-party addons immediately visible by grouping them under one directory without breaking deployment or release workflows.

Status: executed for first-party addons in this phase.

Execution summary:

- First-party addon folders moved under `addons/`.
- `scripts/deploy_addons.sh` updated to deploy first-party addons from `addons/`.
- First-party release workflows updated to package from `addons/` and link to `addons/.../README.md`.
- Root `README.md` links updated to `addons/` paths.

Remaining optional follow-up:

- GuildHangout has been retired and its release workflow removed.

## Target Layout

Planned destination for first-party addons:

- `addons/AscensionPromptSquelcher`
- `addons/AscensionTrinketManager`
- `addons/AscensionVanityHelper`
- `addons/AutoCollect`
- `addons/DialogueReborn`
- `addons/ExtraBarsAscension`
- `addons/MEStats`
- `addons/QuestKeys`

## Scope Guardrails

- Move only first-party addons in one dedicated PR.
- Update scripts/workflows in the same PR.
- Do not combine with feature changes.

## Required Script Updates

- `scripts/deploy_addons.sh`
  - Change root-source lookups to `addons/<name>` where appropriate.
  - Keep path auto-detection for game install roots.
- `create_release.sh`
  - Already supports `addons/<name>` first; keep fallback during transition.
- `scripts/setup_addon_git_sync.sh`
  - No direct dependency on repository addon folder layout (targets game AddOns path).

## Required Workflow Updates

Release workflows currently package from root addon directories and will need path updates:

- `.github/workflows/release-atm.yml`
- `.github/workflows/release-autocollect.yml`
- `.github/workflows/release-avh.yml`
- `.github/workflows/release-mestats.yml`
- `.github/workflows/release-questkeys.yml`
- `.github/workflows/release-extrabars.yml`

Expected workflow packaging change pattern:

- from: `cp -r <AddonName> release/`
- to: `cp -r addons/<AddonName> release/<AddonName>`

## Documentation Updates Required

- Root `README.md` links to addon paths.
- Any release body README links must continue pointing to valid paths.

## Rollback Plan

If migration introduces breakage:

1. Revert the reorganization commit.
2. Re-run release workflow on previous known-good tag.
3. Re-run deploy script from known-good commit.

## Verification Checklist for Migration PR

1. `bash -n scripts/deploy_addons.sh` passes.
2. All release workflows parse without YAML errors.
3. Addon folders exist at new paths and deploy correctly to game AddOns directory.
4. Root README links resolve.
5. At least one test release workflow dry-run (or test tag) succeeds.
