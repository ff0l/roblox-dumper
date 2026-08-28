# Roadmap

Executors still load one file: `dump.lua`.

## Offline analyzer

Correlate dump artifacts without running in-game. The collector already writes `coverage/report.json`, `remotes/graph.json`, `assets/catalog.json`, and `analysis/diffs.jsonl`.

Next:

- Luau AST remote analysis (replace remaining text-scan)
- Dependency graph viewer
- Timeline / snapshot viewer
- Dedicated bytecode pipeline (opcodes, prototypes, CFG)
- Stronger deobfuscation (parameter names, VM unpackers)
- Bounded decompile workers (`Config.threads` is unused; jobs stay sequential)

References: [luau-lang/luau Bytecode.h](https://github.com/luau-lang/luau/blob/master/Common/include/Luau/Bytecode.h), [PumbaaDev/luau-decompiler](https://github.com/PumbaaDev/luau-decompiler).

Do not split `dump.lua` into a package tree the client cannot load.
