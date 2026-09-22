# Hunter Assist Forever

A hunter-only equipped ammunition indicator for WoW Forever (interface 16001). Version 0.5.1 includes the ammo indicator, low pet health icon and Mongoose Bite / Counterattack glow. Range tinting has been removed.

## Install

Replace the existing `Interface/AddOns/HunterAssistForever` folder with the folder in `dist/HunterAssistForever-0.5.1.zip`, then reload the UI. Existing ammo settings are retained. Existing reactive glow settings are retained too; obsolete range settings are ignored.

Open **Settings → AddOns → Hunter Assist Forever**, or type `/haf config`.

## Ammo check

The **Ammo check** settings group enables a movable ammo icon. **Show count** is disabled by default. All four cutoffs are configurable; the defaults are:

| Equipped ammo count | Display |
| --- | --- |
| Above 800 | Hidden |
| 601–800 | Green |
| 401–600 | Yellow |
| 200–400 | Red |
| Below 200 | Red plus a local low-ammo warning |

The addon reads `GetInventoryItemCount("player", ammoSlot)`, the same count used by the character panel's equipped ammo slot. It does not independently sum other ammunition in bags. An empty equipped slot counts as zero. Unavailable or restricted data hides the indicator and does not trigger a warning; a later inventory update or combat ending retries the read.

Warnings appear only on your own screen, once per low-ammo episode. Resupplying to the warning threshold or above rearms the warning; entering the world after a loading screen also rearms it. No raid chat messages are sent.

Keep the cutoffs ordered: **hide > yellow > red > warning**. Press Enter or leave a field to save it. When increasing all cutoffs, start at the top; when decreasing them, start at the bottom. Select **Move icon**, drag the preview, then close settings to finish. The initial position is below the center of the screen, and its position is saved account-wide.

Ammo checks respond to inventory, equipment and world events, with no additional polling loop. They only run for hunters.

## Mongoose Bite / Counterattack glow

Select a default **Action bar** and **Button** under **Mongoose Bite / Counterattack** in `/haf config`. The feature is enabled by default on Bottom right bar, Button 3. Both spells share the selected button, like Holy Strike/Judgement in Paladin Assist Forever. The selection follows a physical button position even when a bar changes pages; choose the position containing your spell or macro.

In combat, that button glows when either learned spell is reported usable by `C_Spell.IsSpellUsable` and is off its own cooldown. Mongoose Bite therefore requires the client's dodge opportunity; Counterattack requires its parry opportunity. Counterattack is ignored until learned, and learned ranks are matched by localized spell name. Insufficient resources or unavailable/restricted usability data do not produce a glow. As in the paladin reminder, a global cooldown alone does not hide a ready opportunity. This is a readiness reminder, not a target-range or facing check.

The bundled LibCustomGlow renderer uses Blizzard's native proc artwork/colors. The glow clears when readiness ends, the selected button is hidden, the feature is disabled, or combat ends. Settings changes release the old button immediately. Buttons are prepared outside combat; newly created buttons encountered in combat wait until combat ends. Spell/cooldown events refresh immediately, with a 0.1-second fallback update only while in combat with an enabled selected button.

## Pet settings

The separate **Pet settings** section controls a silent, red-only low-health icon:

- **Enable low pet health icon** is on by default.
- **Health threshold (%)** defaults to 30 and accepts whole percentages from 1 to 100. The icon appears at or below the threshold and hides above it.
- **Show health percentage** is off by default.
- **Move icon** shows a red preview; drag it and close settings to save its position. Its initial position is beside the ammo icon.

There is no sound or raid-warning message for pet health. The icon hides for absent/dead pets, loading screens, and unavailable/restricted health values. It updates from pet health, maximum health and pet-change events, with no polling loop. It works both in and out of combat when readable data is available. Validate in-game with the pet taking damage and then healing above the threshold.

## Diagnostics and development

`/haf` prints the client version and current equipped ammo count/status. No spell range APIs or deadzone tint hooks are used. The reactive glow retains its combat-only readiness updates.

Run `lua tests/ammo.lua`, `lua tests/reactive.lua`, `lua tests/glow_integration.lua`, `lua tests/pet.lua` and `python3 scripts/package.py`. Tests cover thresholds, warning rearming, restricted values, settings, moving the icon, class gating and upgrading with old saved settings. Real-client verification is still needed for visual layout and API behavior.

The addon follows the module/packaging structure of `paladin-assist-forever` and includes the supplied hunter icon.

## In-game acceptance

- Confirm Ammo check, Mongoose Bite / Counterattack and Pet settings appear in settings and your saved count/position/cutoffs remain intact.
- Compare the count with the equipped ammo slot, including in combat.
- Verify threshold colors, the optional count, Move icon, and the local warning below the threshold.
- Verify no range coloring remains after reloading and the selected reactive button still glows after a dodge when Mongoose Bite is usable and off cooldown.

## API reference

The equipped count follows the [Forever character panel](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua).
