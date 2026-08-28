# Changelog

## 0.4.6

Dropped the fake server tree, `LIMITATIONS.txt`, and duplicate dump files. No `server-visibility.json`, no Studio exporter, no `meta.json` / `script-inventory.json` twins. README describes the collector as it actually runs.

## 0.4.5

Decompile retries bytecode and the script closure, then a rename pass turns `uN`/`vN` into GetService / WaitForChild / ClassName / module-return names. `string.char` folds. Constants that never appear in the decompiled text are listed. Empty decompiler stubs (`-- Empty bytecode`) are not counted as source. Original identifiers are still not in Luau bytecode.

## 0.4.4

Snapshots no longer walk 70k descendants. They diff in-memory remotes/scripts plus leaderstats. Diff lines are counts plus a 40-entry sample, not 150KB of moving-part CFrames. Coverage `percent.instances` is serialized/(serialized+failed); empty schemas stay in `unschematized`.

## 0.4.3

Snapshot overlap. `captureSnapshotState` yields, so Heartbeat started another snapshot before `maxSnapshots` was applied. Reserve the slot and set `Snap.busy` before the walk. Empty class-schema rows are `unschematized`, not `failed`.

## 0.4.2

Readable script files and live I/O that does not stall the client.

- Script artifacts are `scripts/Name.hash8.lua` with a matching `.luau-bytecode`. Identical content still shares one file.
- `appendfile` creates the target file first. Failed append overwrites one file; it does not spawn `*.000591` chunk files.
- Live catalog rewrite is every 30s. Heartbeat flush is 3s.
- `gui-full.json` / `values-all.json` are indexes. Items stay in jsonl.
- `Config.fullProperties` defaults to false (class schemas). Snapshots fingerprint CFrame/Size/Visible without a full `getproperties` pass.
- Luau: FNV uses `bit32.band(h * 16777619, 0xFFFFFFFF)`; `getPlaceName` does not pass `string.gsub`'s count into `safePathSegment`.

## 0.4.1

Potassium client runtime fixes. UniqueId is all zeros on this client, so it is not identity.

- Script discovery is keyed by Instance, not UniqueId. GetDebugId is used when UniqueId is the nil UUID.
- Large tree/GUI payloads stay in jsonl. `trees/*.json` is an index; HttpService cannot encode 20k+ property graphs.
- Non-finite numbers are marked lossy so JSONEncode does not fail the whole file.

## 0.4.0

Evidence/coverage collector. Still one executor file for clients. Still not a server dump.

### Instance graph

- Trees serialize identity (`stableId`, `parentId`, class, name, path) plus class-schema properties. `getproperties` is used when the executor provides it; otherwise BasePart / GUI / Humanoid / Sound / Value / Mesh / Decal schemas apply.
- Path is display metadata. Snapshot diffs key by `stableId`, so a rename is a path change on the same object.
- Unsupported serializer values are `{ type = "unsupported", robloxType, representation, lossy = true }` instead of a fake complete `tostring`.

### Scripts

- Content hashes no longer mix in the instance path. Identical source shares `scripts/<hash>.lua`.
- Raw bytecode is written to `scripts/<hash>.luau-bytecode`, not stuffed into the `.lua` file.
- Confidence is `LOW` / `MEDIUM` / `HIGH` from syntax, proto count, and constant reconstruction — not “valid syntax ⇒ high”.
- Script records distinguish `executionContext` from `visibility`. `serverClassInstance` is still not recovered server source.

### Remotes, coverage, Studio

- Static remote scan follows `local x = …` aliases before `:FireServer`. This is still a text scan, not a Luau AST.
- Catalog emits `remotes/graph.json` (script → remote → observed C2S/S2C).
- `coverage/report.json` plus `complete.json` report what was discovered vs serialized. `server.recovered` is 0 from the client.
- Live append fallback writes chunk files instead of concatenating forever in memory. Events include `complete` and structured `truncated`.
- `studio/DumpPlace.lua` is an authorized Studio exporter (`ScriptEditorService:GetEditorSource`) for places you own.

## 0.3.0

Snapshot/diff collector. Still one executor file. Still not a server dump.

### Accuracy

- Table serializer unmarks after recursion, so shared tables are not reported as cycles. Non-string keys are kept as `{k, v}` entries.
- Static remote hits are `{script, line, expression, method, confidence}`, merged onto matching instances. Catalog confidence is high when an instance is also observed at runtime.
- Scripts report a pipeline (`discovered` → `validated`) with discovery tags, bytecode availability, and `loadstring` syntax validation.
- Script hash changes after the initial dump write a new version instead of being ignored.
- `server-visibility.json` replaces the “server dump” naming. Counts are `scriptInstances`, `serverClassInstances`, `serverOnlyRecovered` (always 0 here).

### Snapshots and schema

- Initial snapshot after dump, then periodic diffs (`snapshots/00000N.json`, `analysis/diffs.jsonl`).
- `manifest.json` describes the output layout. Canonical paths: `scripts/metadata.json`, `remotes/catalog.json`, `remotes/observations.jsonl`, `instances.jsonl`, `analysis/report.json`.
- Live events distinguish RemoteEvent (`role=event`) from RemoteFunction (`role=invoke`).

## 0.2.0

Client collector correctness. This is still one executor file (`dump.lua`). It does not dump unreplicated server source.

### Fixes

- Script files now write a real header plus decompiled source (the old `string.format` template dropped the body).
- Live argument serialization no longer calls an undefined `serializeArg`.
- Unload no longer reads a non-existent `Net.buf`.
- `OnClientInvoke` is wrapped as a callback property. It is not an event; `:Connect` was invalid and could fail inside `pcall`.
- Live `events.jsonl` uses a pending queue that is cleared after flush. The old 500-event ring buffer was re-appended on every write.

### Collector

- Honest client mode: `ServerScriptService` / `ServerStorage` are diagnostic-only in `server-access.json`. They are not treated as recovered server dumps. `Teams` / `MaterialService` are no longer lumped in with those containers.
- Structured serializer for Vector3, Vector2, CFrame, Color3, EnumItem, UDim/UDim2, Ray, BrickColor, NumberRange, NumberSequence, ColorSequence, Rect, PhysicalProperties, and Instance (path, class, name, uniqueId when available). Caps still apply; truncation is recorded on the event.
- Remote catalog is instance-first (path, class, attributes, tags, channel) merged with runtime call counts / last argument types. Source regex is `refs.static` only.
- C2S also hooks `FireServer` / `InvokeServer` via `hookfunction` when present, so `remote.FireServer(...)` is not missed by `__namecall` alone.
- Scripts are content-addressed (`scripts/<hash>.lua`) with `metadata/scripts.json` (hash, first/last seen, decompile status, syntax, confidence).
- `DescendantAdded` records new remotes and scripts after the initial snapshot.

### Docs

- README, LIMITATIONS, and `meta.json` say **client collector**.
- ROADMAP describes a Studio collector and offline analyzer as later components.
