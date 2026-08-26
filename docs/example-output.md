# Example dump output

Trimmed example of what a completed v0.2 client dump looks like. Real dumps are larger.

```
UniversalDumper/13772394625_BladeBall/
  meta.json
  complete.json
  LIMITATIONS.txt
  script-inventory.json
  scripts-index.json
  metadata/scripts.json
  remotes-all.json
  remote-catalog.json
  values-all.json
  gui-full.json
  trees/Workspace.json
  trees/ReplicatedStorage.json
  trees/PlayerGui.json
  scripts/a1b2c3d4e5f60789.lua
  live/events.jsonl
  live/net.log
  live/status.json
  log.txt
```

`meta.json` (shape):

```json
{
  "version": "0.2.0",
  "mode": "client",
  "placeId": 13772394625,
  "placeName": "BladeBall",
  "executor": { "name": "Wave", "version": "" },
  "apis": {
    "decompile": true,
    "getscripts": true,
    "getnilinstances": true,
    "hookmetamethod": true,
    "hookfunction": true
  }
}
```

`metadata/scripts.json` item (shape):

```json
{
  "path": "ReplicatedStorage.Shared.Net",
  "class": "ModuleScript",
  "hash": "a1b2c3d4e5f60789",
  "file": "scripts/a1b2c3d4e5f60789.lua",
  "decompile": "decompiled",
  "syntax": "valid",
  "confidence": "high"
}
```

`remote-catalog.json` item (shape):

```json
{
  "path": "ReplicatedStorage.Network.Inventory.Update",
  "class": "RemoteEvent",
  "channel": "network",
  "refs": { "instance": true, "static": ["ReplicatedStorage.Shared.Net"], "runtime": true },
  "stats": { "c2s": 184, "s2c": 173 },
  "argSchema": ["table"]
}
```

Live argument example (structured, not `tostring`):

```json
{ "type": "Vector3", "x": 0, "y": 5, "z": 10 }
```

`complete.json` (shape):

```json
{
  "ok": true,
  "version": "0.2.0",
  "mode": "client",
  "output": "UniversalDumper/13772394625_BladeBall",
  "scriptsFound": 412,
  "scriptsDumped": 380,
  "message": "Client dump complete. Keep playing — live/events.jsonl captures observed remotes."
}
```
