# Hunter Assist Forever: deadzone saturation

Approved scope: hunter-only icon coloring across all eight default Blizzard action bars, including paged main-bar slots. No glow and no custom-bar integration. Only confirmed too-close ranged abilities become desaturated red; too-far, in-range, unknown, invalid and missing targets retain native appearance. Melee abilities remain unchanged.

The native AddOns settings panel contains one bordered group named **Range checks** and one checkbox named **Deadzone saturation**, enabled by default. Store the boolean account-wide in HunterAssistForeverDB. Changes apply immediately; disabling restores native icon state. The panel is available on all classes; range processing runs only for hunters. `/haf config` opens settings; `/haf` prints diagnostics.

Use the paladin project's private Lua namespace, Core / Services / Features / SettingsPanel / Bootstrap structure, TOC interface 16001, standalone Lua tests and an installable versioned ZIP. Do not bundle glow libraries for this feature.

Range evidence uses current learned harmful spells and their live minimum/maximum range metadata. A tracked spell needs a positive minimum range. It is confirmed too close only if its range result is explicitly false and a learned harmful spell with no minimum range and a maximum no greater than the tracked maximum is explicitly in range. This rules out the far side without assuming a fixed distance or using coordinates. Missing, restricted or contradictory results never independently cause tint. Evidence is recomputed for the chosen living attackable unit each update. Coverage depends on learned probes; especially early levels may have insufficient evidence.

Cache the learned spell catalog until spell/talent changes. Cache default button enumeration between discovery events and a 0.5-second fallback. Check current slots and displayed spells each 0.1-second refresh; cache range results by spell within that refresh. No distance checks with no valid target, no per-frame spellbook scan, and no polling while disabled or on other classes. Macros may use the client-reported displayed spell; the indicator always describes the current target, not alternate macro targets.

Use secure post-hooks on icon coloring/desaturation to preserve the latest native state and keep the tint through native refreshes. Do not replace protected handlers, alter attributes, cast, or change bindings. Prepare hooks outside combat; late-created unprepared buttons wait until combat ends. Restore colors and desaturation on disable, changed actions, invalid target, lost evidence and hidden buttons.

Local tests cover false-positive prevention, API normalization/restricted values, side bars/paging/duplicate actions, native appearance restoration, saved settings, checkbox behavior, class gating, throttling and manifest startup. In-client acceptance is required for range API behavior, combat taint and visual layout.

## Spellbook fallback and diagnostics (0.1.2)

Keep the learned spellbook slot and bank alongside each spell ID. Prefer the readable spellbook-slot range answer; fall back to the spell-ID API only for unavailable, restricted, missing or failing slot checks. A definite false is not a fallback condition. Cache both the selected result and safe status labels once per spell per refresh. Preserve the existing confirmed-too-close inference.

`/haf` prints the current checked spell names/IDs, range bounds, statuses from both APIs, selected API and confirming proximity spell. It makes no extra diagnostic-only range calls, prints no restricted values or error payloads, and emits no stale evidence while disabled.

## Target and mouseover selection (0.1.2)

A selected target takes priority and must be living and attackable. Only when UnitExists("target") explicitly returns false may a living attackable mouseover be selected. A friendly, dead or unreadable selected target does not fall back to mouseover. Both API checks and all proximity evidence use the same chosen unit for the entire refresh. Target and mouseover events refresh immediately; 0.1-second polling handles mouseover departure. Diagnostics identifies the chosen unit. The single existing checkbox controls both paths.

## Ammo indicator (0.2.0)

Add a separate Ammo check settings group with enable checkbox (default true), Show count (default false), and ordered positive integer cutoffs (800/600/400/200). Use the equipped ammo slot texture and count, following the native character panel. Empty slot is zero; unreadable data is unknown and produces no warning. Display green/yellow/red according to thresholds, hidden above the highest cutoff. An ordinary movable frame shows the ammo texture and optional count; position is saved account-wide through a settings preview.

Inventory/equipment events refresh ammunition without range polling. Warn locally once below the lowest cutoff; rearm after resupply or world entry. Suppress checks while leaving/loading the world. Keep the range and ammo feature lifecycles independent, with hunter gating shared by Core. Tests cover thresholds, warnings, loading, restricted values, settings validation and dragging. Real-client acceptance remains necessary.

## Creature-independent proximity fallback (0.2.1)

Tame Beast was the useful zero-minimum-range spell on the user's hunter, but it did not confirm proximity to humanoids. The user tested CheckInteractDistance(unit, 3) successfully in combat against both beasts and humanoids. Keep learned spell evidence, then fall back to that nearby interaction check if no spell succeeds. Require a readable negative shot range and a shot maximum of at least 10 yards; a positive interaction check only rules out the far side. Cache all interaction outcomes once per refresh on the same target/mouseover selected for spell checks. Errors, missing APIs, nil and restricted values provide no evidence. Diagnostics report interaction status and attribution. Automated tests cover combined behavior; the packaged change still requires client acceptance.

## Reactive ability glow (0.3.0)

Use the paladin addon's LibCustomGlow proc renderer, native colors and fixed default-bar/button selector. One shared selected button glows in combat if a learned Mongoose Bite or Counterattack is usable and off its own cooldown. Match learned spellbook ranks by localized names from rank-one spell metadata. Ignore GCD-only cooldowns like the paladin feature. Treat restricted/unknown usability and cooldown evidence conservatively. No combat-log dodge/parry timers, casts, bindings or range checks are added to this reminder. The client's usability state is authoritative and needs validation after a dodge/parry in-game.

Feature defaults enabled with no selected bar. Prepare overlay parents outside combat, refresh on spell/usability/cooldown/combat events, and poll at 0.1 seconds only while enabled, in combat and with a selected button. Stop on world exit, disable or combat exit. Bundle library license files. Tests cover readiness, cooldowns, rank/learning changes, selection cleanup, native rendering and existing features.

## Range feature removal (0.4.1)

Remove deadzone range tinting and its settings, range APIs and polling. Retain both the ammo indicator and Mongoose Bite / Counterattack reactive glow, including its bundled library, selected button and saved preferences. The initial ammo-only 0.4.0 build was superseded after the user clarified that the reactive glow should stay.

## Pet health indicator (0.5.0)

Separate Pet settings group, enabled by default with 30% configurable threshold, optional health percentage off by default, and a movable red-only icon. The user found raid warnings too loud, so this feature is a silent visual alert with no warning messages or sounds. Hidden above threshold; shown at or below it. Hide for missing/dead pets and unknown/restricted health. Read UnitHealth/UnitHealthMax only after readability guards and finite positive checks, using current pet unit events and world lifecycle events. Preserve ammo and reactive glow behavior. In-game validation of the health APIs and settings layout remains necessary.
