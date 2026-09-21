# Hunter Deadzone Saturation Implementation Plan

> Execute inline using the executing-plans workflow, with test-driven implementation and verification at each step.

**Goal:** Color ranged ability icons desaturated red only when the current target is confirmed too close, with a single saved checkbox.

**Architecture:** Follow Paladin Assist Forever's private namespace and modular structure. Client adapts public APIs, Range combines two spell range checks, Buttons enumerates default bars, IconTint preserves native appearance, and Deadzone coordinates updates. Core and Bootstrap own lifecycle; Config and SettingsPanel own saved preferences and native controls.

**Tech Stack:** Lua, WoW Forever interface 16001, native Settings/frame APIs, Python standard-library ZIP packaging.

**Spec:** `docs/design.md`.

## Global constraints

- Default Blizzard bars only, hunter-only processing; current living attackable target.
- Exact labels: Range checks / Deadzone saturation; enabled by default.
- No glow, melee coloring, coordinates, protected action changes or custom-bar support.
- False/unknown/restricted range evidence must never be treated as a confirmed close target on its own.
- Preserve native appearance and saved disabled preferences.

## Task 1: Range evidence and client adapters

Files: `Services/Client.lua`, `Services/Range.lua`, `tests/run.lua`, `tests/helpers.lua` under the addon/repository roots.

- [x] Write failing tests for `Range:Rebuild()` and `Range:BeginUpdate()` / `Range:IsTooClose(id)` using learned spells with literal ranges: shot 8–35, close probe 0–15, distant probe 0–100. Shot=false + close=true must tint; shot=false + distant=true alone must not. Include nil, restricted, dead/friendly targets, unlearned spells and duplicate query caching.
- [x] Run `lua tests/run.lua`; confirm missing implementation failures.
- [x] Implement public API adapters and per-refresh evidence. Enumerate player spellbook only during rebuild; filter harmful, learned spells and exclude pets/passives.
- [x] Run the range tests; fix until green.

## Task 2: Default bars, rendering and lifecycle

Files: `Core.lua`, `Services/Buttons.lua`, `Services/IconTint.lua`, `Features/Deadzone.lua`, `Bootstrap.lua`, manifest and integration tests.

- [x] Write tests that put the same shot on a main and side button, transition close → far, change a paged slot to melee, simulate native color/desaturation updates, hide a button, disable the feature and start on a non-hunter.
- [x] Run the tests and confirm missing behavior.
- [x] Enumerate eight standard prefixes, resolve live action slots and displayed macro spells. Securely post-hook only texture presentation methods outside combat and preserve native state for restoration.
- [x] Connect 0.1-second polling, spellbook invalidation, 0.5-second discovery fallback and immediate target/settings refresh. Remove polling when disabled.
- [x] Run the integration tests; confirm both restoration and bounded range query counts.

## Task 3: Settings, diagnostics and release

Files: `Services/Config.lua`, `Services/SettingsWidgets.lua`, `SettingsPanel.lua`, `README.md`, `scripts/package.py` and tests.

- [x] Test default enabled, saved false retained, checkbox immediately restoring/reapplying icons, one bordered group, `/haf config` opening the category and manifest load order.
- [x] Reuse the paladin Config and SettingsWidgets patterns trimmed to this single boolean and checkbox; add range diagnostics without revealing restricted values.
- [x] Run all Lua tests and parse each Lua file with `luac -p`.
- [x] Document installation, evidence limitations and in-game acceptance checks. Build `dist/HunterAssistForever-0.1.0.zip` with one top-level addon directory and verify archive entries and manifest.
- [x] Review code for combat safety, stale tints, false far-range positives, unnecessary polling and native-state restoration. Report actual verification results and the remaining in-game checks.

## Verification result

19 range tests and 26 integration tests pass. All 13 Lua source/test files parse with luac. The 11-file installable archive matches the source bytes. Independent code review found no actionable correctness issues. Real-client range coverage, combat safety and visual checks remain explicitly documented in README.md.
