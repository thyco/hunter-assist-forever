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
