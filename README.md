# roblox-dumper

Client-side Roblox place collector. Trees, remotes, GUI, scripts, live telemetry, snapshots.

This is a **client collector**, not a server dumper. Unreplicated `ServerScriptService` / `ServerStorage` source is invisible from a normal client. For a place you own, that belongs in a Studio collector (see [ROADMAP.md](ROADMAP.md)).

One file: `dump.lua`. Execute it in a place. Output goes to `UniversalDumper/[placeId]_PlaceName/` in the executor workspace.

v0.3.0 research tool, not a game script pack.

## What it dumps

- Instance trees plus `instances.jsonl`
- RemoteEvent / RemoteFunction / UnreliableRemoteEvent index (instance + static refs with line/method + runtime stats)
- GUI, values, attributes
- Scripts with discovery tags, decompile/syntax/validation pipeline, content-addressed files
- Structured Roblox types (Vector3, CFrame, Color3, Instance, table key types preserved)
- Live C2S / S2C intercept (`OnClientInvoke` is wrapped as a callback, not `:Connect`)
- Periodic snapshots and diffs after the initial dump

Quiet by default (`Config.debug = false`).

## Run

1. Join a place.
2. Execute `dump.lua`.
3. Open the folder in `WHERE.txt` / `complete.json`. Keep playing — `snapshots/` and `live/events.jsonl` keep updating.

## How it works

```
resolve executor APIs
  → create UniversalDumper/<placeId>_<name>/
  → remotes, values, GUI, trees
  → optional live hooks (Config.liveInstallEarly)
  → collect + decompile scripts (content-addressed, validated)
  → remote catalog merge
  → snapshot 000001 + manifest.json
  → runtime: remotes/scripts, pending event flush, snapshot diffs
```

Scripts are unioned from `GetDescendants`, `getscripts` / `getrunningscripts` / `getloadedmodules`, and `getnilinstances` if `Config.includeNil` is on. Each script reports a pipeline: discovered → identified → source/bytecode → decompile attempted → validated.

Live C2S uses `__namecall` plus `hookfunction` on `FireServer` / `InvokeServer` when available. S2C RemoteEvents use `OnClientEvent`. RemoteFunctions wrap `OnClientInvoke` and record return values separately (`role = invoke`).

## Output

```
UniversalDumper/<place>/
  manifest.json
  metadata.json
  complete.json
  LIMITATIONS.txt
  server-visibility.json
  instances.jsonl
  scripts/metadata.json
  scripts/<hash>.lua
  remotes/catalog.json
  remotes/observations.jsonl
  snapshots/000001.json
  analysis/diffs.jsonl
  analysis/report.json
  live/events.jsonl
  trees/*.json
  log.txt
```

`server-visibility.json` is the client view of non-replicated containers, not a server dump. `serverOnlyRecovered` is always 0 from this collector.

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
| `snapshotDiff` | `true` | Periodic snapshots after the initial dump |
| `snapshotEvery` | `20` | Seconds between snapshots |
| `maxSnapshots` | `10` | Snapshot cap |
| `debug` | `false` | Console logging |
| `skipCore` | `true` | Skip CoreGui / Chat / CorePackages |

Need `writefile` + `makefolder` to save. Everything else degrades: missing `decompile` means stubs or bytecode.

## Limits

Client dump only. An empty `ServerScriptService` / `ServerStorage` tree is expected. See `LIMITATIONS.txt`.

## License

Reuse is fine. Give credit — keep ff0l and a link to this repo somewhere obvious. See [LICENSE](LICENSE).
