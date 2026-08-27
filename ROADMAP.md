# Roadmap

v0.4 is a client collector with an instance graph, coverage report, and a first Studio exporter. Executors still load one file (`dump.lua`).

## Studio collector (authorized places)

[`studio/DumpPlace.lua`](studio/DumpPlace.lua) dumps editor source via [ScriptEditorService:GetEditorSource](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService). Run it as a Studio plugin for a place you own. The client collector must not pretend this is possible from a live game.

`--!native` server scripts may compile to machine code. A Studio exporter should not assume every script is a recoverable bytecode blob. See [Luau native code generation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/luau/native-code-gen.md).

Later: merge Studio + client artifacts in the analyzer using `stableId` / `contentHash`.

## Offline analyzer

Correlate client (and Studio) artifacts without running in-game. v0.4 already writes `coverage/report.json`, `remotes/graph.json`, `assets/catalog.json`, and `analysis/diffs.jsonl`.

Next:

- Luau AST remote analysis (replace remaining text-scan)
- Dependency graph viewer
- Timeline / snapshot viewer
- Dedicated bytecode pipeline (opcodes, prototypes, CFG)
- Stronger deobfuscation (parameter names, VM unpackers) — v0.4.5 is GetService/WaitForChild/ClassName/return only
- Bounded decompile workers (job queue exists sequentially; `Config.threads` is unused)

References: [luau-lang/luau Bytecode.h](https://github.com/luau-lang/luau/blob/master/Common/include/Luau/Bytecode.h), [PumbaaDev/luau-decompiler](https://github.com/PumbaaDev/luau-decompiler).

## Target layout

```
roblox-dumper/
  dump.lua              # client collector (this release)
  studio/DumpPlace.lua  # authorized Studio exporter
  analyzer/             # offline graphs, diffs, bytecode (not in this release)
```

Do not split `dump.lua` into a package tree the client cannot load.
