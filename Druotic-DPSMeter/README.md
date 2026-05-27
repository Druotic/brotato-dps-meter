# DPSMeter - Accurate Real-Time DPS Overlay

This Brotato mod adds a lightweight in-run overlay that displays:
- Rolling **window damage** (actual HP removed, not requested damage / no overkill)
- Rolling **DPS** for each player
- A small pie chart representing each player's share for the current rolling window
- Damage dealt by **charmed enemies** is attributed to the player who charmed them

## Accuracy improvements

Many damage mods rely on “damage dealt” counters that can include overkill (requested damage applied to low-HP targets). This mod instead records **the `actual_dmg` returned by the enemy/neutral `take_damage()` call**, so totals reflect what was actually removed.

Charmed-enemy damage is additionally captured by detecting whether the **attacker** is charmed, then attributing damage to the charmer.

## Configuration (optional)

If **Oudstand-ModOptions** is installed, configure via:

`Options → Mods → DPSMeter`

Options:
- Enable overlay
- Opacity
- Rolling DPS window seconds
- Show/hide window damage and DPS

Without ModOptions, defaults are used:
- Enabled: `true`
- Opacity: `1.0`
- Window seconds: `5.0`
- Show damage: `true`
- Show DPS: `true`

