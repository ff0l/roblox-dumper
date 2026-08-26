# Changelog

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
