# roblox-dumper

Client-side Roblox place dumper. Trees, remotes, GUI, scripts, optional live hooks.

One file: `dump.lua`. Execute it in a place. Output goes to `UniversalDumper/[placeId]_PlaceName/` in the executor workspace.

This is a research tool, not a game script pack.

## What it dumps

- Instance trees (Workspace, ReplicatedStorage, PlayerGui, related roots)
- RemoteEvent / RemoteFunction catalog
- GUI hierarchy
- Scripts from descendants plus executor APIs (`getscripts`, etc.)
- Decompile when the executor has `decompile` (bytecode fallback)
- Attributes, values, metadata
- Optional live C2S / S2C intercept after the static dump

Quiet by default (`Config.debug = false`).

## Run

1. Join a place.
2. Execute `dump.lua`.
3. Open the folder in `WHERE.txt` / `complete.json`.

## How it works

```
resolve executor APIs
  → create UniversalDumper/<placeId>_<name>/
  → remotes, values, GUI, trees
  → collect + decompile scripts
  → optional net / live hooks
  → complete.json + log.txt
```

`dumpTrees` walks selected service roots. Core services (`Chat`, `CoreGui`, `CorePackages`) are skipped when `Config.skipCore` is true.

Scripts are unioned from `GetDescendants`, `getscripts` / `getrunningscripts` / `getloadedmodules`, and `getnilinstances` if `Config.includeNil` is on. Decompile uses a per-script timeout (`Config.timeout`, default 6s) and caches by `getscripthash` when that exists.

## Output

```
UniversalDumper/
  123456789_PlaceName/
    meta.json
    complete.json
    LIMITATIONS.txt
    scripts/*.lua
    remotes-all.json
    remote-catalog.json
    values-all.json
    gui-full.json
    trees/*.json
    live/                  (if hooks stay installed)
    log.txt
```

Trimmed example: [docs/example-output.md](docs/example-output.md)

## Config

Edit the `Config` table at the top of `dump.lua`.

| Key | Default | Meaning |
|-----|---------|---------|
| `decompile` | `true` | Call executor decompiler |
| `maxScripts` | `2000` | Cap on dumped scripts |
| `maxTreePerRoot` | `60000` | Tree node cap per root |
| `hookNet` | `true` | Namecall hooks after dump |
| `liveIntercept` | `true` | Record live remote traffic |
| `debug` | `false` | Console logging |
| `skipCore` | `true` | Skip CoreGui / Chat / CorePackages |

Need `writefile` + `makefolder` to save. Everything else degrades: missing `decompile` means stubs or bytecode.

## Limits

Client dump only. ServerScriptService / ServerStorage that never replicates is invisible. Every dump writes `LIMITATIONS.txt` with the same note.

## License

Source available. See `LICENSE`. Not licensed for reuse.
