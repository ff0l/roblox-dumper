# Example dump output

Trimmed example of a v0.3 client dump. Real dumps are larger.

```
UniversalDumper/13772394625_BladeBall/
  manifest.json
  metadata.json
  complete.json
  LIMITATIONS.txt
  server-visibility.json
  script-inventory.json
  instances.jsonl
  scripts/metadata.json
  scripts/a1b2c3d4e5f60789.lua
  remotes/catalog.json
  remotes/observations.jsonl
  snapshots/000001.json
  snapshots/000002.json
  analysis/diffs.jsonl
  analysis/report.json
  live/events.jsonl
  trees/ReplicatedStorage.json
  log.txt
```

`manifest.json` (shape):

```json
{
  "schema": "roblox-dumper/v0.3",
  "version": "0.3.0",
  "mode": "client",
  "files": {
    "scripts": "scripts/metadata.json",
    "remotes": "remotes/catalog.json",
    "instances": "instances.jsonl",
    "snapshots": "snapshots/"
  }
}
```

Script metadata item (shape):

```json
{
  "path": "ReplicatedStorage.Shared.Net",
  "class": "ModuleScript",
  "hash": "a1b2c3d4e5f60789",
  "discovery": ["descendants", "getloadedmodules"],
  "decompile": "decompiled",
  "syntax": "valid",
  "validation": "passed",
  "confidence": "high",
  "versions": 1,
  "serverOnlyRecovered": false
}
```

Remote catalog item (shape):

```json
{
  "path": "ReplicatedStorage.Network.Inventory.Update",
  "class": "RemoteEvent",
  "channel": "network",
  "confidence": "high",
  "refs": {
    "instance": true,
    "runtime": true,
    "static": [
      { "script": "ReplicatedStorage.Shared.Net", "line": 184, "method": "FireServer", "confidence": "medium" }
    ]
  },
  "stats": { "c2s": 193, "s2c": 181 }
}
```

Live argument example:

```json
{ "type": "Vector3", "x": 0, "y": 5, "z": 10 }
```
