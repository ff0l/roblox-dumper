# roblox-dumper

Client-side Roblox place collector. Instance graph, remotes, GUI, scripts, live telemetry, snapshots, coverage.

This is a **client collector**, not a server dumper. Unreplicated `ServerScriptService` / `ServerStorage` source is invisible from a normal client. For a place you own, run [`studio/DumpPlace.lua`](studio/DumpPlace.lua) from a Studio plugin (`ScriptEditorService:GetEditorSource`).

One executor file: `dump.lua`. Output goes to `UniversalDumper/[placeId]_PlaceName/` in the executor workspace.

v0.4.0 research tool, not a game script pack.

## What it dumps

- Instance graph: `stableId` / `parentId` plus class-schema properties (or `getproperties` when present)
- RemoteEvent / RemoteFunction / UnreliableRemoteEvent index, alias-aware static refs, `remotes/graph.json`
- GUI, values, attributes, asset content IDs
- Scripts with discovery tags, reconstruction scoring (`LOW`/`MEDIUM`/`HIGH`), content-addressed `.lua` plus raw `.luau-bytecode`
- Structured Roblox types; unsupported values are marked `lossy`
- Live C2S / S2C intercept (`OnClientInvoke` is wrapped as a callback, not `:Connect`)
- Periodic snapshots keyed by stable id, plus `coverage/report.json`

Quiet by default (`Config.debug = false`).

## Run

1. Join a place.
2. Execute `dump.lua`.
3. Open the folder in `WHERE.txt` / `complete.json`. Keep playing — `snapshots/` and `live/events.jsonl` keep updating.
4. For a place you own, also run `studio/DumpPlace.lua` in Studio (plugin context). Merge later; do not treat the client dump as a server dump.

## How it works

```
capability detection + session metadata
  → remotes, values, GUI, instance graph, assets
  → optional live hooks (Config.liveInstallEarly)
  → sequential script jobs (decompile → serialize → write)
  → remote catalog + graph
  → snapshot 000001 + coverage/report.json
  → runtime: remotes/scripts, pending event flush, snapshot diffs
```

Scripts are unioned from `GetDescendants`, `getscripts` / `getrunningscripts` / `getloadedmodules`, and `getnilinstances` if `Config.includeNil` is on. Each script reports a pipeline: discovered → identified → source/bytecode → decompile attempted → reconstruction score.

Live C2S uses `__namecall` plus `hookfunction` on `FireServer` / `InvokeServer` when available. S2C RemoteEvents use `OnClientEvent`. RemoteFunctions wrap `OnClientInvoke` and record return values separately (`role = invoke`).

## Output

```
UniversalDumper/<place>/
  manifest.json
  metadata.json
  complete.json
  coverage/report.json
  LIMITATIONS.txt
  server-visibility.json
  instances.jsonl
  scripts/metadata.json
  scripts/<hash>.lua
  scripts/<hash>.luau-bytecode
  remotes/catalog.json
  remotes/graph.json
  remotes/observations.jsonl
  assets/catalog.json
  snapshots/000001.json
  analysis/diffs.jsonl
  analysis/report.json
  live/events.jsonl
  trees/*.json
  log.txt
```

`server-visibility.json` is the client view of non-replicated containers, not a server dump. `serverOnlyRecovered` is always 0 from this collector. `coverage/report.json` is the completeness claim.

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
| `liveFlushEvery` | `8` | Flush pending live events this often |
| `snapshotDiff` | `true` | Periodic snapshots after the initial dump |
| `snapshotEvery` | `20` | Seconds between snapshots |
| `maxSnapshots` | `10` | Snapshot cap |
| `debug` | `false` | Console logging |
| `skipCore` | `true` | Skip CoreGui / Chat / CorePackages |
| `threads` | `1` | Reserved; decompile stays sequential |

Need `writefile` + `makefolder` to save. Everything else degrades: missing `decompile` means stubs or bytecode files.

## Limits

Client dump only. An empty `ServerScriptService` / `ServerStorage` tree is expected. See `LIMITATIONS.txt`. Static remotes are still a text scan (alias-aware), not a full Luau AST.

## License

Reuse is fine. Give credit — keep ff0l and a link to this repo somewhere obvious. See [LICENSE](LICENSE).
