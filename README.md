# Hunter Assist Forever

A hunter-only equipped ammunition indicator for WoW Forever (interface 16001). Version 0.6.4 includes ammo, pet health and happiness indicators, and the Mongoose Bite / Counterattack glow. Range tinting has been removed.

## Install

Replace the existing `Interface/AddOns/HunterAssistForever` folder with the folder in `dist/HunterAssistForever-0.6.4.zip`, then reload the UI. Existing ammo settings are retained. Existing reactive glow settings are retained too; obsolete range settings are ignored.

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

Ammo checks wait three seconds after login or a loading screen before reading the equipped slot, to avoid warnings from temporarily empty inventory data. Early inventory events wait too; normal inventory and equipment updates are immediate afterward. No polling loop is added. They only run for hunters.

## Mongoose Bite / Counterattack glow

Select a default **Action bar** and **Button** under **Mongoose Bite / Counterattack** in `/haf config`. The feature is enabled by default on Bottom right bar, Button 3. Both spells share the selected button, like Holy Strike/Judgement in Paladin Assist Forever. The selection follows a physical button position even when a bar changes pages; choose the position containing your spell or macro.

In combat, that button glows when either learned spell is reported usable by `C_Spell.IsSpellUsable` and is off its own cooldown. Mongoose Bite therefore requires the client's dodge opportunity; Counterattack requires its parry opportunity. Counterattack is ignored until learned, and learned ranks are matched by localized spell name. Insufficient resources or unavailable/restricted usability data do not produce a glow. As in the paladin reminder, a global cooldown alone does not hide a ready opportunity. This is a readiness reminder, not a target-range or facing check.

The bundled LibCustomGlow renderer uses Blizzard's native proc artwork/colors. The glow clears when readiness ends, the selected button is hidden, the feature is disabled, or combat ends. Settings changes release the old button immediately. Buttons are prepared outside combat; newly created buttons encountered in combat wait until combat ends. Spell/cooldown events refresh immediately, with a 0.1-second fallback update only while in combat with an enabled selected button.

## Pet settings

The separate **Pet settings** section controls two pet icons. The low-health icon is red when active:

- **Enable low pet health icon** is on by default.
- **Health threshold (%)** defaults to 30 and accepts whole percentages from 1 to 100. The icon appears at or below the threshold and hides above it.
- **Show health percentage** is off by default.
- **Move icon** shows a red preview; drag it and close settings to save its position. Its initial position is beside the ammo icon.

The separate **pet happiness icon** is hidden when happy, yellow when content, and red when unhappy. Enable it with **Enable pet happiness icon** (on by default). **Move happiness icon** lets you place it independently of the health icon; it starts to the right of the health icon. Happiness uses Forever's `C_PetInfo.GetPetHappiness` API and updates from pet events, with no polling loop. Missing, dead, or unreadable pet data hides it.

When readable health first falls to or below its threshold, or happiness first becomes unhappy, a local raid-style warning appears with a gentle whisper chime. Each alert fires once until the pet recovers; content stays visual only. If both alerts occur together, both messages appear with one chime. No raid chat message is sent. When Forever restricts pet health, a client-side percentage curve can still make the red icon visible below the threshold without exposing the value to the addon. In that visual-only mode, the health percentage and low-health sound warning are unavailable. The icons hide for absent or dead pets and during loading; an unavailable happiness value hides its icon. Pet events update both icons without a polling loop.

## Diagnostics and development

`/haf` prints the client version and current ammo, pet health and pet happiness status. No spell range APIs or deadzone tint hooks are used. The reactive glow retains its combat-only readiness updates.

Run `lua tests/ammo.lua`, `lua tests/reactive.lua`, `lua tests/glow_integration.lua`, `lua tests/pet.lua` and `python3 scripts/package.py`. Tests cover thresholds, warning rearming, restricted values, settings, moving the icon, class gating and upgrading with old saved settings. Real-client verification is still needed for visual layout and API behavior.

The addon follows the module/packaging structure of `paladin-assist-forever` and includes the supplied hunter icon.

## In-game acceptance

- Confirm Ammo check, Mongoose Bite / Counterattack and Pet settings appear in settings and your saved count/position/cutoffs remain intact.
- Compare the count with the equipped ammo slot, including in combat.
- Verify threshold colors, the optional count, Move icon, and the local warning below the threshold.
- Confirm the happiness icon is hidden when happy, yellow when content, and red when unhappy. Feed your pet or let its happiness change; verify the icon updates without a reload. Test moving it independently.
- Check that readable low health and unhappy each show a local warning with a gentle chime once per episode, while content stays quiet. When `/haf` reports pet health as visual only, check that the red health icon still follows the threshold; no low-health sound is expected in that mode. Confirm the low-ammo warning still uses its original sound.
- Verify no range coloring remains after reloading and the selected reactive button still glows after a dodge when Mongoose Bite is usable and off cooldown.

## API reference

The equipped count follows the [Forever character panel](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua). Pet happiness uses the [Forever pet API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PetInfoDocumentation.lua).
