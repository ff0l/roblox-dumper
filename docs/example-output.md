# Example dump output

Trimmed example of what a completed dump looks like. Real dumps are larger.

```
UniversalDumper/13772394625_BladeBall/
  meta.json
  complete.json
  LIMITATIONS.txt
  script-inventory.json
  scripts-index.json
  remotes-all.json
  remote-catalog.json
  values-all.json
  gui-full.json
  trees/Workspace.json
  trees/ReplicatedStorage.json
  trees/PlayerGui.json
  scripts/0001_ReplicatedStorage.Shared.Net.lua
  scripts/0002_PlayerScripts.Local.Combat.lua
  log.txt
```

`meta.json` (shape):

```json
{
  "placeId": 13772394625,
  "placeName": "BladeBall",
  "executor": { "name": "Wave", "version": "" },
  "apis": {
    "decompile": true,
    "getscripts": true,
    "getnilinstances": true,
    "hookmetamethod": true
  }
}
```

`complete.json` (shape):

```json
{
  "ok": true,
  "output": "UniversalDumper/13772394625_BladeBall",
  "scriptsFound": 412,
  "scriptsDumped": 380,
  "message": "Dump complete. Keep playing — net-live.log captures live remotes."
}
```
