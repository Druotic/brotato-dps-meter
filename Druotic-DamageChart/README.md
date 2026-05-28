# Damage Chart - Real-Time Damage Visualization

This Brotato mod adds a lightweight in-run overlay that displays:
- Total wave damage (actual HP removed, not requested damage / no overkill)
- Average wave DPS for each player (`damage so far / seconds so far`)
- A small pie chart representing each player's share of wave damage
- Damage dealt by **charmed enemies** is attributed to the player who charmed them

## Accuracy improvements

Many damage mods rely on “damage dealt” counters that can include overkill (requested damage applied to low-HP targets). This mod instead records **the `actual_dmg` returned by the enemy/neutral `take_damage()` call**, so totals reflect what was actually removed.

Charmed-enemy damage is additionally captured by detecting whether the **attacker** is charmed, then attributing damage to the charmer.

## Configuration (optional)

If **Oudstand-ModOptions** is installed, configure via:

`Options -> Mods -> Damage Chart`

Options:
- Hide Damage Chart (Solo)

Without ModOptions, defaults are used:
- Chart is visible in solo and co-op.

## Publishing to Steam Workshop

Workshop item: [3734086003](https://steamcommunity.com/sharedfiles/filedetails/?id=3734086003)

From the repository root:

1. Build deploy artifacts:
   ```bash
   ./scripts/build-dist.sh
   ```
2. In Steam, switch Brotato to the **modding** game version (`Properties -> Betas -> modding`).
3. Launch Brotato and choose **Launch Game Editor** (Workshop uploader), not the game.
4. In the uploader, provide:
   - **Mod ZIP:** `<repo root>/dist/Damage Chart.zip`
   - **Mod Image:** `<repo root>/dist/workshop_preview.png`
   - **Workshop ID:** `3734086003` (updates the existing item)

After upload, Steam may take a few seconds to propagate the update to subscribed clients.
