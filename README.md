# roblox-dumper

Client-side Roblox place collector. Trees, remotes, GUI, scripts, optional live telemetry.

This is a **client collector**, not a server dumper. Unreplicated `ServerScriptService` / `ServerStorage` source is invisible from a normal client. For a place you own, that belongs in a Studio collector (see [ROADMAP.md](ROADMAP.md)).

One file: `dump.lua`. Execute it in a place. Output goes to `UniversalDumper/[placeId]_PlaceName/` in the executor workspace.

v0.2.0 research tool, not a game script pack.

## What it dumps

- Instance trees (Workspace, ReplicatedStorage, PlayerGui, related roots)
- RemoteEvent / RemoteFunction / UnreliableRemoteEvent index (instances + runtime stats; regex is a secondary signal)
- GUI hierarchy
- Scripts from descendants plus executor APIs (`getscripts`, etc.)
- Decompile when the executor has `decompile` (bytecode fallback, syntax/confidence fields)
- Attributes, values, structured Roblox types (Vector3, CFrame, Color3, Instance, …)
- Optional live C2S / S2C intercept after (or during) the static dump

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
  → optional live hooks (Config.liveInstallEarly)
  → collect + decompile scripts (content-addressed)
  → remote catalog merge
  → complete.json + log.txt
  → runtime: new remotes/scripts, pending event flush
```

`dumpTrees` walks selected service roots. Core services (`Chat`, `CoreGui`, `CorePackages`) are skipped when `Config.skipCore` is true.

Scripts are unioned from `GetDescendants`, `getscripts` / `getrunningscripts` / `getloadedmodules`, and `getnilinstances` if `Config.includeNil` is on. Decompile uses a per-script timeout (`Config.timeout`, default 6s) and caches by `getscripthash` when that exists.

Live C2S uses `__namecall` plus `hookfunction` on `FireServer` / `InvokeServer` when available. S2C RemoteEvents use `OnClientEvent`. RemoteFunctions wrap the `OnClientInvoke` **callback** (it is not an event).

## Output

```
UniversalDumper/
  123456789_PlaceName/
    meta.json
    complete.json
    LIMITATIONS.txt
    metadata/scripts.json
    scripts/<hash>.lua
    scripts-index.json
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
| `hookNet` | `true` | Namecall / method hooks after dump |
| `liveIntercept` | `true` | Record live remote traffic |
| `liveInstallEarly` | `true` | Install hooks before decompile |
| `debug` | `false` | Console logging |
| `skipCore` | `true` | Skip CoreGui / Chat / CorePackages |

Need `writefile` + `makefolder` to save. Everything else degrades: missing `decompile` means stubs or bytecode.

## Limits

Client dump only. `server-access.json` is a diagnostic of the client view of `ServerScriptService` / `ServerStorage`. An empty tree is expected, not a failed server dump. Every dump writes `LIMITATIONS.txt` with the same note.

## License

Reuse is fine. Give credit — keep ff0l and a link to this repo somewhere obvious. See [LICENSE](LICENSE).
