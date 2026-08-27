# Example dump output

Trimmed example of a v0.4 client dump. Real dumps are larger.

```
UniversalDumper/13772394625_BladeBall/
  manifest.json
  metadata.json
  complete.json
  coverage/report.json
  LIMITATIONS.txt
  server-visibility.json
  script-inventory.json
  instances.jsonl
  scripts/metadata.json
  scripts/a1b2c3d4e5f60789.lua
  scripts/a1b2c3d4e5f60789.luau-bytecode
  remotes/catalog.json
  remotes/graph.json
  remotes/observations.jsonl
  assets/catalog.json
  snapshots/000001.json
  analysis/diffs.jsonl
  analysis/report.json
  live/events.jsonl
  trees/ReplicatedStorage.json
  log.txt
```

`manifest.json` (shape):

```json
{
  "schema": "roblox-dumper/v0.4",
  "schemaVersion": 1,
  "collectorVersion": "0.4.0",
  "mode": "client",
  "files": {
    "scripts": "scripts/metadata.json",
    "remotes": "remotes/catalog.json",
    "remoteGraph": "remotes/graph.json",
    "coverage": "coverage/report.json",
    "instances": "instances.jsonl",
    "snapshots": "snapshots/"
  }
}
```

Instance graph row (shape):

```json
{
  "stableId": "01f2…",
  "parentId": "01aa…",
  "class": "Part",
  "name": "Part",
  "path": "Workspace.Map.Part",
  "complete": false,
  "properties": {
    "Size": { "type": "Vector3", "x": 4, "y": 1, "z": 2 },
    "Anchored": true
  }
}
```

Script metadata item (shape):

```json
{
  "path": "ReplicatedStorage.Shared.Net",
  "stableId": "01f2…",
  "class": "ModuleScript",
  "contentHash": "a1b2c3d4e5f60789",
  "file": "scripts/a1b2c3d4e5f60789.lua",
  "bytecode_file": "scripts/a1b2c3d4e5f60789.luau-bytecode",
  "discovery": ["descendants", "getloadedmodules"],
  "executionContext": "unknown",
  "visibility": "replicated",
  "decompile": "decompiled",
  "syntax": "valid",
  "confidence": "MEDIUM",
  "reconstructionScore": 65,
  "serverOnlyRecovered": false
}
```

Remote catalog item (shape):

```json
{
  "path": "ReplicatedStorage.Network.Inventory.Update",
  "stableId": "01bb…",
  "class": "RemoteEvent",
  "channel": "network",
  "discovery": ["descendants", "static-source", "runtime"],
  "confidence": "HIGH",
  "refs": {
    "instance": true,
    "runtime": true,
    "static": [
      { "script": "ReplicatedStorage.Shared.Net", "line": 184, "method": "FireServer", "confidence": "medium", "kind": "text-scan" }
    ]
  },
  "stats": { "c2s": 193, "s2c": 181 }
}
```
