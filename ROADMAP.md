# Roadmap

v0.3 is a client collector with snapshots and a formal output layout, still in one executor file.

## Studio collector (authorized places)

For a place you own or have permission to inspect, dump from Studio. The client cannot reconstruct unreplicated `ServerScriptService` / `ServerStorage`.

Intended surface:

- Server tree (`ServerScriptService`, `ServerStorage`, server modules)
- Script source via [ScriptEditorService](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService) (`GetEditorSource`, script documents)
- Place metadata
- Server remote handlers when they exist as Studio source

`--!native` server scripts may compile to machine code. A Studio exporter should not assume every script is a recoverable bytecode blob. See [Luau native code generation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/luau/native-code-gen.md).

## Offline analyzer

Correlate client (and later Studio) artifacts without running in-game. v0.3 already writes `analysis/diffs.jsonl` and `remotes/catalog.json`; a viewer would consume those:

- Remote graph (instance ↔ scripts ↔ observed C2S/S2C)
- Dependency graph
- Timeline / snapshot viewer
- Dedicated Luau bytecode pipeline (opcodes, prototypes, CFG)

References: [luau-lang/luau Bytecode.h](https://github.com/luau-lang/luau/blob/master/Common/include/Luau/Bytecode.h), [PumbaaDev/luau-decompiler](https://github.com/PumbaaDev/luau-decompiler).

## Target layout (later)

```
roblox-dumper/
  dump.lua              # client collector (this release)
  studio/               # Studio plugin / command-bar exporter
  analyzer/             # offline graphs, diffs, bytecode
```

Executors still need a single Lua file. Do not split `dump.lua` into a package tree the client cannot load.
