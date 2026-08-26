# Roblox Game Dumper

Universal Roblox place dumper for research and reverse engineering.

Writes structured dumps under `UniversalDumper/[placeId]_PlaceName/` in your executor workspace.

## Usage

Execute `dump.lua` in your executor while in a game.

## Output

- Instance trees
- Remote events and functions
- GUI hierarchy
- Decompiled scripts (when supported)
- Attributes and metadata

## Requirements

- Luau executor with `writefile`, `makefolder`, and optional `decompile`
- Debug logging disabled by default (`Config.debug = false`)

## Configuration

Edit the `Config` table at the top of `dump.lua` to toggle decompilation, tree limits, and live hooks.
