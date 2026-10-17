# Hunter Assist Forever

A hunter-only helper for WoW Forever (interface 16001). Version 0.8.19 includes ammo, pet health and happiness indicators, a combat reminder for Aspect of the Cheetah / Pack, and separate Mongoose Bite and Counterattack glows. Range tinting has been removed.

## Install

Replace the existing `Interface/AddOns/HunterAssistForever` folder with the folder in `dist/HunterAssistForever-0.8.19.zip`, then reload the UI. Existing settings are retained; obsolete range settings are ignored.

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

## Mongoose Bite and Counterattack glows

Each spell has its own settings group in `/haf config`, with an enable checkbox and separate **Action bar** and **Button** choices. The eight bar positions are labeled **Action bar 1** through **Action bar 8**. Mongoose Bite defaults to Action bar 3, Button 3; an existing reactive-glow selection migrates to Mongoose Bite. Counterattack is enabled but starts with no bar selected, so choose its button after learning the spell. Each selection follows a physical button position even when a bar changes pages; choose the position containing that spell or macro.

Each glow also has **Use Blizzard native glow** (on by default) and its own **Custom glow color** picker, as in Warrior Assist Forever. Uncheck native glow to use the chosen color. Changes to either setting update an active glow immediately; switching native back on restores Blizzard's original colors. The two choices are saved independently.

**Show Counterattack icon overlay** is on by default. During a Counterattack opportunity, it shows the Counterattack icon over the selected button with a separate GCD swipe. It hides when the opportunity ends, Counterattack enters its own cooldown, combat ends, or the setting is disabled. The action, key binding and tooltip remain those of the original button. Its cooldown keeps running but is covered visually while the Counterattack icon appears; the overlay never chooses or casts a spell. The existing proc glow can be toggled independently. The overlay is prepared outside combat, so a newly selected button during combat may need to wait until combat ends before its overlay appears.

In combat, each selected button glows when its learned spell is reported usable by `C_Spell.IsSpellUsable` and is off its own cooldown. Mongoose Bite therefore requires the client's dodge opportunity; Counterattack requires its parry opportunity. Counterattack is ignored until learned, and learned ranks are matched by localized spell name. The API's insufficient-resource result also counts as an available opportunity, and a confirmed glow stays visible through a global cooldown. A successful cast of either reactive spell clears its glow immediately, even if cooldown timing is restricted during the GCD. The consumed opportunity remains hidden until the client reports it inactive, or until the spell's own cooldown has been observed and then finishes; this lets a new proc during cooldown glow afterward. A real spell cooldown, expired opportunity, or unavailable/restricted usability data also clears that spell's glow. This is a readiness reminder, not a target-range or facing check.

The bundled LibCustomGlow renderer uses Blizzard's native proc artwork/colors. Each glow clears when its own readiness ends, its selected button is hidden, its checkbox is disabled, or combat ends. Settings changes release the old button immediately. Buttons are prepared outside combat; newly created buttons encountered in combat wait until combat ends. Spell/cooldown events refresh immediately, with a 0.1-second fallback update only while in combat with an enabled selected button.

## Aspect reminder

The **Aspect reminder** settings group has two independent checkboxes: **Show active Cheetah / Pack icon** and **Glow around aspect icon**. Both are on by default. In combat, a 64×64 icon appears while your Aspect of the Cheetah or Aspect of the Pack buff is active, using that aspect's artwork. It hides when the buff ends, combat ends, the feature is disabled, or the world is loading. The glow uses Blizzard's native proc artwork/colors and can be disabled while keeping the icon. There is no sound or raid warning.

Select **Move icon** to preview and drag it. The preview can show outside combat; closing settings returns it to combat-only behavior. The icon starts below the center of the screen and saves its position account-wide. Player aura and combat events drive updates, without a new polling loop. If Forever marks the aura data as restricted, the reminder hides rather than guessing its state. A glow may wait until the next combat if the UI was reloaded during combat, because its frame must be prepared outside combat.

## Pet settings

The separate **Pet settings** section controls two pet icons. The low-health icon is red when active:

- **Enable low pet health icon** is on by default.
- **Health threshold (%)** defaults to 35 and accepts whole percentages from 1 to 100. The icon appears at or below the threshold, including out of combat, and hides above it.
- **Show health percentage** is off by default.
- **Flash screen at low pet health** is on by default. In combat, a translucent edge effect pulses while the pet is at or below the same threshold, leaving the center of the screen clear. Turn it off if you prefer the icon and warning text alone.
- **Flash color** opens WoW's color picker. The default is amber; your selected color is saved and applies immediately without changing the pulse timing or strength.
- **Pulse intensity (%)** defaults to 150 and accepts whole percentages from 10 to 300. Values above 100 layer the same edge effect for a stronger pulse. Changes apply immediately, including during a Test pulse preview.
- **Test pulse** previews the edge effect at its normal intensity, even with a healthy pet or outside combat. Click again or close settings to stop it. The preview never sends a warning or plays a sound.
- **Move icon** shows a red preview; drag it and close settings to save its position. Its initial position is beside the ammo icon.

The separate **pet happiness icon** is hidden when happy, yellow when content, and red when unhappy. Enable it with **Enable pet happiness icon** (on by default). **Move happiness icon** lets you place it independently of the health icon; it starts to the right of the health icon. Happiness uses Forever's `C_PetInfo.GetPetHappiness` API and updates from pet events, with no polling loop. Missing, dead, or unreadable pet data hides it.

When readable pet health first falls to or below its threshold during combat, a local raid-style warning appears with a gentle whisper chime. If the pet is already low when combat begins, the warning appears then. It fires once until the pet recovers; leaving and re-entering combat does not repeat it for the same low-health episode. Happiness warnings remain independent: an unhappy pet shows its local warning and chime even out of combat, while content stays visual only. If both alerts occur together, both messages appear with one chime. No raid chat message is sent. When Forever restricts pet health, a client-side percentage curve drives the red icon, and in combat also drives a large centered **Pet health low!** warning and the optional screen-edge pulse. The text and pulse hide on combat exit or recovery. Restricted values cannot trigger a one-time `RaidNotice_AddMessage` or sound because Lua cannot detect the threshold crossing; the health percentage is also unavailable. The indicators hide for absent or dead pets and during loading; an unavailable happiness value hides its icon. Pet events update them without a Lua polling loop; the screen pulse uses a client animation.

## Diagnostics and development

`/haf` prints the client version and current ammo, pet and aspect status. No spell range APIs or deadzone tint hooks are used. The reactive glow retains its combat-only readiness updates.

For a reactive glow that stays hidden after its spell cooldown ends, enable temporary diagnostics with `/haf reactive-debug`. When it happens, use `/haf reactive-log mongoose` or `/haf reactive-log counterattack` to print the last 40 state changes for that spell. The log stays in memory for this session only; run `/haf reactive-debug` again to turn it off and clear it. Diagnostics do not change the glow decision.

Run `lua tests/ammo.lua`, `lua tests/reactive.lua`, `lua tests/glow_integration.lua`, `lua tests/pet.lua`, `lua tests/aspect.lua` and `python3 scripts/package.py`. Tests cover thresholds, warning rearming, restricted values, settings, moving the icons, class gating and upgrading with old saved settings. Real-client verification is still needed for visual layout and API behavior.

The addon follows the module/packaging structure of `paladin-assist-forever` and includes the supplied hunter icon.

## In-game acceptance

- Confirm Ammo check, separate Mongoose Bite and Counterattack glow settings, Pet settings and Aspect reminder appear, and your saved count/position/cutoffs remain intact. Your previous reactive-glow button should now be Mongoose Bite's selection; Counterattack should have no selected bar.
- Compare the count with the equipped ammo slot, including in combat.
- Verify threshold colors, the optional count, Move icon, and the local warning below the threshold.
- Confirm the happiness icon is hidden when happy, yellow when content, and red when unhappy. Feed your pet or let its happiness change; verify the icon updates without a reload. Test moving it independently.
- In Pet settings, click **Test pulse** with a healthy pet and confirm the colored edges appear and the center stays clear. Change **Pulse intensity (%)** while the preview is running and compare 50, 150, and 250; the pulse should strengthen without restarting. Click Test pulse again or close settings to stop it. If the preview is invisible, report that before testing the health trigger.
- Check that the low-health icon can appear out of combat while its warning text, chime and screen-edge pulse wait until combat begins. On combat exit, the text and pulse should hide while the icon remains if the pet is still low. An unhappy pet continues to warn out of combat. When `/haf` reports pet health as visual only, check that the red icon follows the threshold and, in combat, the centered **Pet health low!** text and edge pulse do too; no low-health sound is expected in that mode. Choose another **Flash color** while the pulse is visible and confirm it changes immediately; canceling the picker should restore the old color. Turn off **Flash screen at low pet health** and confirm the icon and text remain. Confirm the low-ammo warning still uses its original sound.
- Verify no range coloring remains after reloading. Select a separate Counterattack button after learning it; each button should glow only for its own dodge/parry opportunity, stay lit through the global cooldown, and clear when that spell enters its own cooldown. The Counterattack icon overlay should cover that button during its proc and show the GCD swipe; hovering or pressing the button should still use its original action.
- Activate Cheetah or Pack out of combat: the aspect icon should stay hidden. Enter combat: the larger matching icon and glow should appear. Cancel or change the aspect: the icon should clear or change. Turn off only the glow checkbox: the icon should remain. Try Move icon to place it.

## API reference

The equipped count follows the [Forever character panel](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua). Pet happiness uses the [Forever pet API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PetInfoDocumentation.lua). The aspect reminder uses the [Forever player aura API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) and [spell texture API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
