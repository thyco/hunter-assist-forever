# Hunter Assist Forever

A hunter-only addon for WoW Forever that colors ranged ability icons **desaturated red when your current target is confirmed too close**. Version 0.1.1 supports all eight default Blizzard action bars, including side bars and main-bar paging. It does not add a glow or change melee ability icons.

## Install

1. Extract `dist/HunterAssistForever-0.1.1.zip` into your client's `Interface/AddOns` directory, or copy the repository's `HunterAssistForever` folder there.
2. Confirm the resulting path is `Interface/AddOns/HunterAssistForever/HunterAssistForever.toc` with no extra nested directory.
3. Enable **Hunter Assist Forever** in the character-selection AddOns menu and log in as a hunter. Restart the client if a newly installed addon does not appear.

The manifest targets Forever interface **16001**, matching the paladin addon. Local tests cannot establish in-game compatibility; see the acceptance checks below.

The AddOns list uses the supplied hunter artwork, bundled as a 256×256 transparent TGA in `HunterAssistForever/Media/Hunter.tga`.

## Settings

Open **Settings → AddOns → Hunter Assist Forever**, or type `/haf config`.

The bordered **Range checks** group contains one checkbox: **Deadzone saturation**. It is enabled by default. Changes apply immediately and are saved account-wide across reloads and logouts. Turning it off restores Blizzard's current icon colors and desaturation and stops range polling. Settings remain accessible on other classes, but range processing only runs on hunters.

No bar or button selection is needed. Direct spell buttons and macros whose displayed spell the client exposes are checked automatically. For macros, the tint describes the **displayed spell against your current target**; it does not evaluate focus, mouseover, conditionals, or an entire cast sequence. Items, pet abilities, flyouts, custom bars and unidentified macro actions are not colored.

## What counts as too close

The addon uses learned harmful spells and their current minimum/maximum range metadata. It colors an ability only when both conditions hold:

- The ability has a positive minimum range and the client explicitly reports it out of range.
- A learned harmful spell with no minimum range and a maximum no greater than that ability's maximum range is explicitly in range of the same target.

The second check rules out the far side. Merely being out of shooting range is insufficient: distant targets must not turn the icons red. The indicator also applies inside melee distance, where minimum-range shots are still too close. Range evidence does not depend on mana or cooldown readiness.

No valid living attackable target, missing spell information, nil/restricted range results or insufficient evidence leave native appearance unchanged. Attackable neutral targets are supported. A single long-range spell such as Hunter's Mark cannot establish proximity to a shorter-range shot.

**Coverage depends on your learned spells and Forever's API results.** If your only useful probe reaches melee distance, the gap just outside melee may remain uncolored. Missing evidence is intentionally not guessed. Spell metadata and hitbox behavior must be checked on the actual client; this is not an exact distance meter and it does not indicate facing, line of sight, ammunition or overall castability.

## Performance and presentation

Range checks run at most once per 0.1-second polling interval, with immediate refreshes for target and settings changes. Duplicate spells share one range query per refresh. The learned-spell catalog is rebuilt on relevant events; default button discovery runs on bar changes and every 0.5 seconds. Polling resolves live slots so moved spells, pages and displayed macro spells update correctly. No range API calls run without a valid target, and the polling handler is removed while disabled or on non-hunters.

Icon writes happen on state transitions or when Blizzard updates an actively tinted icon. Secure post-hooks preserve the latest native color/desaturation so mana shading and lock shading return when the tint clears. No protected action attributes, bindings, macros or cast commands are modified. Existing default buttons are prepared outside combat. Late-created buttons first encountered in combat wait until combat ends before their icons can be tinted.

## Diagnostics

Type `/haf` to print the client build/interface, whether the feature is enabled, the number of available proximity probes, default buttons and confirmed-too-close buttons. If nothing colors, test with a living attackable target, check that the setting is enabled, and include this output and any Lua errors in the report.

## Development

This project follows `paladin-assist-forever`'s Lua namespace and module layout. The Config and settings widget patterns are adapted from that project. No glow libraries or other runtime dependencies are needed.

| Module | Responsibility |
| --- | --- |
| `Core.lua` | Hunter gating, registered features and settings lifecycle. |
| `Services/Client.lua` | Range, spellbook and action APIs; readable-value checks. |
| `Services/Range.lua` | Learned spell catalog, per-refresh cache and proximity evidence. |
| `Services/Buttons.lua` | All eight default Blizzard button groups. |
| `Services/IconTint.lua` | Secure texture hooks, tinting and native appearance restoration. |
| `Services/Config.lua` | Validated account-wide boolean settings and change listeners. |
| `Services/SettingsWidgets.lua` | Reusable bordered section and checkbox helpers. |
| `Features/Deadzone.lua` | Applies confirmed proximity to visible ranged buttons. |
| `SettingsPanel.lua` | Native AddOns category with the single checkbox. |
| `Bootstrap.lua` | Events, throttled updates and `/haf` commands. |

Run from the repository root with Lua 5.4 and Python 3.9+ installed:

```sh
lua tests/run.lua
lua tests/integration.lua
python3 scripts/package.py
```

The production addon uses WoW-compatible Lua syntax. Tests load the actual modules and manifest against WoW API/frame doubles, including native texture updates. They verify range decisions, unknown/restricted evidence, caching, all bars, paging, macros, combat transitions, appearance restoration, saved settings, checkbox behavior, class gating and polling. They do not simulate Blizzard's secure execution environment or render the actual settings panel.

## In-game acceptance

- Enable Lua errors with `/console scriptErrors 1`, then `/reload`.
- Open `/haf config`; confirm one **Range checks** box with **Deadzone saturation** checked.
- Place ranged spells on several visible default bars. Approach a living attackable target from beyond maximum range: far away and valid shooting distance must retain native icons; confirmed too close should turn them desaturated red. Continue into melee distance. Repeat while in combat and on targets with different hitbox sizes.
- If the gap just outside melee does not color, report `/haf` output and your learned abilities; a suitable readable probe may be unavailable.
- Check melee spells remain unchanged. Clear the target, select a friendly/dead unit or return to shooting distance; red must clear.
- Move abilities, change bar pages and hide/show bars. Only the current visible ranged actions should be tinted. Test any macros you use according to the displayed-spell/current-target scope above.
- While red is active, toggle the checkbox off and on. Confirm immediate restoration/reapplication, including when low on mana. Disable, reload and confirm it stays disabled.
- Log in on a non-hunter: settings should remain available without coloring or range processing.
- Watch for Lua errors or blocked-action/taint messages in combat; none are expected, but this requires real-client verification.

## API references

The implementation was checked against the Forever branch of the Blizzard UI source mirror:

- [Spell range and metadata APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [Player spellbook APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua)
- [Default button native coloring and macro spell handling](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua)
