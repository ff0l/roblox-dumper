# roblox-dumper

Client-side Roblox place dumper for research and reverse engineering.

Lua · Luau · executor APIs

Execute `dump.lua` in a game. Output lands under `UniversalDumper/[placeId]_PlaceName/` in the executor workspace.

## Features

- Instance trees (Workspace, ReplicatedStorage, PlayerGui, and related roots)
- RemoteEvent / RemoteFunction catalog
- GUI hierarchy
- Script collection from descendants plus executor APIs
- Decompile when the executor exposes `decompile` (bytecode fallback)
- Attributes, values, and metadata
- Optional live C2S / S2C intercept after the static dump
- Quiet by default (`Config.debug = false`)

## Tech stack

| Layer | Tech |
|-------|------|
| Language | Luau |
| Runtime | Roblox client + executor |
| Output | JSON + `.lua` files via `writefile` / `makefolder` |

## Architecture

```
boot
  → resolve executor APIs (decompile, getscripts, writefile, hooks)
  → probe filesystem
  → create UniversalDumper/<placeId>_<name>/
  → dump remotes, values, GUI, trees
  → collect + decompile scripts
  → optional net / live hooks
  → write complete.json + log.txt
```

### How traversal works

`dumpTrees` walks selected service roots and writes `trees/<label>.json`. Core Roblox services (`Chat`, `CoreGui`, `CorePackages`) are skipped when `Config.skipCore` is true.

### How scripts are collected

`collectAllScripts` unions several sources and de-duplicates by instance path:

1. `game:GetDescendants()`
2. `getscripts` / `getrunningscripts` / `getloadedmodules` when present
3. `getnilinstances` when `Config.includeNil` is true
4. Best-effort walk of server containers (usually empty from the client)

### How decompilation works

If `decompile` (or `disassemble`) exists, each script is decompiled with a per-script timeout (`Config.timeout`, default 6s). Results are cached by `getscripthash` when available. If decompile fails and `includeBytecode` is on, bytecode is written instead.

### Output format

```
UniversalDumper/
  123456789_PlaceName/
    meta.json
    complete.json
    LIMITATIONS.txt
    script-inventory.json
    scripts-index.json
    scripts/0001_....lua
    remotes-all.json
    remote-catalog.json
    values-all.json
    gui-full.json
    trees/*.json
    live/                  (if live hooks stay installed)
    log.txt
```

See [docs/example-output.md](docs/example-output.md) for a trimmed example.

## Configuration

Edit the `Config` table at the top of `dump.lua`.

| Key | Default | Meaning |
|-----|---------|---------|
| `decompile` | `true` | Call executor decompiler |
| `maxScripts` | `2000` | Cap on dumped scripts |
| `maxTreePerRoot` | `60000` | Tree node cap per root |
| `hookNet` | `true` | Install namecall hooks after dump |
| `liveIntercept` | `true` | Record live remote traffic |
| `debug` | `false` | Console logging |
| `skipCore` | `true` | Ignore CoreGui / Chat / CorePackages |

## Executor compatibility

Works best when the executor provides:

- `writefile`, `makefolder` (required to save)
- `decompile` or `disassemble`
- `getscripts` / `getrunningscripts` / `getloadedmodules`
- `getnilinstances`, `getscriptbytecode`, `getscripthash`
- `hookmetamethod` for live intercept

Missing APIs degrade gracefully: the dump still writes trees and remotes; scripts may stay as stubs or bytecode.

## Known limitations

This is a **client** dump. It cannot see ServerScriptService / ServerStorage content that never replicates. `LIMITATIONS.txt` is written into every dump folder with the same notes.

## Usage

1. Join a place.
2. Execute `dump.lua`.
3. Open the folder printed in `WHERE.txt` / `complete.json`.
