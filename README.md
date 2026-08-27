# roblox-dumper

One Lua file that snapshots a Roblox place from an executor: scripts, remotes, instances, GUI, values, and live traffic while you play.

Execute [`dump.lua`](dump.lua). Output lands in the executor workspace under `UniversalDumper/<placeId>_<PlaceName>/`.

**v0.4.6**

## Run

1. Join a place.
2. Execute `dump.lua` (Potassium, Wave, or any executor with `writefile` / `makefolder`).
3. Open `WHERE.txt` in that folder when it appears.
4. Keep playing. `live/events.jsonl` and `snapshots/` keep updating until you leave or unload.

Re-running the same session unloads the previous collector first (`UNIVERSAL_DUMP_UNLOAD`). For a clean folder, delete the old `UniversalDumper/<place>/` directory before you dump again.

## What you get

**Scripts** — Every LocalScript, ModuleScript, and replicated Script the client can see (`GetDescendants`, `getscripts`, `getloadedmodules`, `getnilinstances`). Each unique bytecode hash becomes one file:

- `scripts/Name.hash8.lua` — decompiled source, then a rename pass (`GetService`, `WaitForChild`, `ClassName`, module return)
- `scripts/Name.hash8.luau-bytecode` — raw bytecode
- `scripts/Name.hash8.constants.json` — `getconstants` on the closure
- `scripts/metadata.json` — path, hash, confidence, reconstruction score

Identical source shares one pair of files. Confidence is `LOW` / `MEDIUM` / `HIGH` from syntax, proto count, and constant overlap.

**Remotes** — RemoteEvent, RemoteFunction, UnreliableRemoteEvent, plus Bindables. Catalog, static refs from decompiled source, and live C2S/S2C counts.

**Instances** — Workspace, ReplicatedStorage, ReplicatedFirst, StarterGui, StarterPack, LocalPlayer, Lighting. Identity (`stableId`, `parentId`, class, name, path) plus class-schema properties. Full rows in `instances.jsonl`; `trees/*.json` are indexes.

**GUI & values** — PlayerGui / StarterGui objects, ValueBases, and attributes as jsonl.

**Live** — After the first pass, hooks stay on:

| Direction | What |
|-----------|------|
| C2S | `FireServer` / `InvokeServer` (`__namecall` + `hookfunction`) |
| S2C | `OnClientEvent`; `OnClientInvoke` is wrapped as a callback |
| STAT | leaderstats / health |
| INST | remotes or scripts that appear later |

**Snapshots** — Up to 10 diffs of remotes, scripts, and leaderstats. No full-tree walk.

## Output

```
UniversalDumper/<placeId>_<PlaceName>/
  WHERE.txt                 path to this folder
  complete.json             summary when the first pass finishes
  manifest.json             file index, version, placeId
  metadata.json             session, executor APIs, Config
  log.txt                   phase log
  coverage/report.json      discovered vs dumped
  scripts/
    metadata.json
    KnitClient.95245fd0.lua
    KnitClient.95245fd0.luau-bytecode
    KnitClient.95245fd0.constants.json
  remotes/
    catalog.json            every remote + bindable
    graph.json              static refs + observed edges
    observations.jsonl      same events as live, per remote
  live/
    events.jsonl            structured traffic
    net.log                 tab-separated traffic
    status.json
  instances.jsonl           one instance per line
  trees/Workspace.json      index → instances.jsonl
  gui.jsonl
  values.jsonl
  assets/catalog.json       rbxassetid references
  snapshots/000001.json
  analysis/
    report.json
    diffs.jsonl             counts + a 40-entry sample
```

`complete.json` is the first-pass snapshot. Live files keep growing after that.

## How it works

```
detect APIs
  → remotes, values, GUI, instance graph, assets
  → live hooks (default: before decompile)
  → decompile each script → rename pass → write .lua + bytecode
  → remote catalog + graph
  → snapshot 000001
  → Heartbeat: flush live events, snapshot diffs
```

Decompile tries the instance, then the bytecode blob, then the script closure. Empty stubs are not saved as source.

The rename pass maps decompiler names (`u1`, `v3`) from real APIs and types. Parameters like `p9` stay when there is no name to recover — Luau bytecode does not store original locals.

## Config

Edit the `Config` table at the top of `dump.lua`.

| Key | Default | Meaning |
|-----|---------|---------|
| `decompile` | `true` | Call the executor decompiler |
| `deobfuscate` | `true` | Rename `uN`/`vN` from APIs and types |
| `dumpScriptConstants` | `true` | Write `scripts/*.constants.json` |
| `includeBytecode` | `true` | Write `.luau-bytecode` |
| `includeNil` | `true` | Also scan `getnilinstances` |
| `maxScripts` | `2000` | Cap on dumped scripts |
| `dumpTrees` | `true` | Instance graph |
| `maxTreePerRoot` | `60000` | Cap per tree root |
| `fullProperties` | `false` | Use `getproperties` on every instance |
| `dumpGui` | `true` | PlayerGui / StarterGui |
| `maxGui` | `20000` | GUI row cap |
| `dumpValues` | `true` | ValueBases + attributes |
| `dumpRemotes` | `true` | Remote catalog |
| `hookNet` | `true` | Install live hooks |
| `liveIntercept` | `true` | Record C2S / S2C / STAT |
| `liveInstallEarly` | `true` | Hooks before decompile |
| `liveFlushEvery` | `8` | Flush pending events this often |
| `snapshotDiff` | `true` | Periodic snapshots after the first pass |
| `snapshotEvery` | `20` | Seconds between snapshots |
| `maxSnapshots` | `10` | Snapshot cap |
| `skipCore` | `true` | Skip CoreGui / Chat / CorePackages |
| `replaceUsername` | `true` | Redact your username in paths |
| `timeout` | `6` | Seconds per script decompile |
| `debug` | `false` | Console logging |

You need `writefile` and `makefolder`. Missing `decompile` still writes bytecode files when `getscriptbytecode` exists.

## License

Reuse is fine. Keep **ff0l** and a link to [github.com/ff0l/roblox-dumper](https://github.com/ff0l/roblox-dumper) somewhere obvious. See [LICENSE](LICENSE).
