# Hunter Assist Forever: deadzone saturation

Approved scope: hunter-only icon coloring across all eight default Blizzard action bars, including paged main-bar slots. No glow and no custom-bar integration. Only confirmed too-close ranged abilities become desaturated red; too-far, in-range, unknown, invalid and missing targets retain native appearance. Melee abilities remain unchanged.

The native AddOns settings panel contains one bordered group named **Range checks** and one checkbox named **Deadzone saturation**, enabled by default. Store the boolean account-wide in HunterAssistForeverDB. Changes apply immediately; disabling restores native icon state. The panel is available on all classes; range processing runs only for hunters. `/haf config` opens settings; `/haf` prints diagnostics.

Use the paladin project's private Lua namespace, Core / Services / Features / SettingsPanel / Bootstrap structure, TOC interface 16001, standalone Lua tests and an installable versioned ZIP. Do not bundle glow libraries for this feature.

Range evidence uses current learned harmful spells and their live minimum/maximum range metadata. A tracked spell needs a positive minimum range. It is confirmed too close only if its range result is explicitly false and a learned harmful spell with no minimum range and a maximum no greater than the tracked maximum is explicitly in range. This rules out the far side without assuming a fixed distance or using coordinates. Missing, restricted or contradictory results never independently cause tint. Evidence is recomputed for the current living attackable target each update. Coverage depends on learned probes; especially early levels may have insufficient evidence.

Cache the learned spell catalog until spell/talent changes. Cache default button enumeration between discovery events and a 0.5-second fallback. Check current slots and displayed spells each 0.1-second refresh; cache range results by spell within that refresh. No distance checks with no valid target, no per-frame spellbook scan, and no polling while disabled or on other classes. Macros may use the client-reported displayed spell; the indicator always describes the current target, not alternate macro targets.

Use secure post-hooks on icon coloring/desaturation to preserve the latest native state and keep the tint through native refreshes. Do not replace protected handlers, alter attributes, cast, or change bindings. Prepare hooks outside combat; late-created unprepared buttons wait until combat ends. Restore colors and desaturation on disable, changed actions, invalid target, lost evidence and hidden buttons.

Local tests cover false-positive prevention, API normalization/restricted values, side bars/paging/duplicate actions, native appearance restoration, saved settings, checkbox behavior, class gating, throttling and manifest startup. In-client acceptance is required for range API behavior, combat taint and visual layout.
