# dsh-tool-nu

**Model-facing Nushell tool for DeepSeek Harness — a curated bash-style command set on Windows, without WSL/Git Bash.**

Registers a `nu` tool for every agent in the profile. Each call runs a fresh Nushell that loads the [bash-for-windows](https://github.com/sv222/bash-for-windows) compatibility layer, so common bash commands have familiar spellings. It is a command/alias layer on top of Nushell — not a bash interpreter. See [What this is not](#what-this-is-not).

## Why

- DSH's native `bash` tool is disabled on Windows (needs WSL).
- `pwsh` is slow to start and lacks bash muscle memory.
- This plugin gives agents a fast, native, bash-style shell backed by [Nushell](https://nushell.sh).

## Features

- `ll`, `la`, `l`, `lh`, `lt`, `ltr`, `lsd`, `lsf` — enhanced listings
- `grep`, `grepi` — pattern search with case options
- `head`, `tail` — first/last N. Accepts every bash spelling (`head 5`, `head -5`, `head -n 5`, `head --lines 5`) and works on both lists/tables and text piped from external commands
- `wc` — `{lines, words, chars}` by default; `wc -l` / `-w` / `-c` print a plain number
- `uniq` — collapses *adjacent* duplicates (bash semantics, unlike Nushell's built-in `uniq`, which dedupes globally); supports `-c`, `-d`, `-u`, `-i`
- `sort`, `cut` — text processing
- `ps`, `psg`, `psk`, `top`, `free`, `uptime`, `whoami` — system management
- `kill-by-name`, `kill-by-port` — process termination
- `g`, `gs`, `ga`, `gc`, `gco`, `gd`, `gl`, `gp`, `gpl`, `gb`, `gba`, `gr` — git shortcuts
- `zip`, `unzip` — archives
- `..`, `...`, `....` — quick navigation

## What this is not

Nushell is not bash, and this layer only covers the commands it defines. Real bash syntax does **not** work here:

| bash | this tool |
|---|---|
| `x=1; echo $x` | ✗ use `let x = 1` |
| `$(pwd)` / `` `pwd` `` | ✗ use `(pwd)` |
| `2>&1`, `2>/dev/null` | ✗ use Nushell redirection |
| `for i in 1 2; do ...; done` | ✗ use `for i in [1 2] { ... }` |
| `f() { ... }` | ✗ use `def f [] { ... }` |
| `&&` / `\|\|` | ✗ use `;` / `and` / `or` |

Pipelines between the aliases do work, because they are ordinary Nushell commands:

```nu
^ls -1 | grep "tool" | head -3
"b\na\nc\n" | sort | uniq -c
```

If you need real bash syntax on Windows, use [dsh-tool-brush](https://github.com/lilyco-42/dsh-tool-brush) — or run both plugins side by side and let the agent pick.

## Install

```sh
# Recommended — works out of the box
dsh plugin --profile web add github:lilyco-42/dsh-tool-nu
```

Restart `dsh web`. The `nu` tool appears in every agent's catalog.

### Installing from a local checkout

`dsh plugin add <path>` installs through pnpm's `link:` protocol, so the profile points at your checkout instead of copying it. Node then resolves this plugin's `@deepseek-ai/*` imports from the **checkout's** directory tree, which never reaches the profile's `node_modules` — and the plugin fails to load with:

```
Cannot find package '@deepseek-ai/schemastery' imported from <checkout>/lib/index.js
```

Make dsh's own modules reachable from the checkout (Windows, no admin required):

```powershell
New-Item -ItemType Junction `
  -Path "<checkout>\node_modules\@deepseek-ai" `
  -Target "$env:USERPROFILE\.dsh\profiles\node_modules\@deepseek-ai"

dsh plugin --profile web add <checkout>
```

`<DSH_HOME>\profiles\node_modules\@deepseek-ai` is the directory dsh provisions itself (one link per in-box package, ~240 of them), so the plugin resolves the **same module instances** dsh is running.

> Do not "fix" this with a plain `pnpm install` inside the checkout. It pulls a second copy of `@deepseek-ai/dsh-tools`, `dsh-llm`, … into the checkout. The plugin then loads, but `instanceof HarnessError` and `Symbol()`-keyed lookups compare against a different module instance than the host's.

## Requirements

- [Nushell](https://nushell.sh) 0.114+ in PATH (e.g. `winget install nushell`, scoop, or chocolatey)
- DeepSeek Harness 0.1.0-rc.6+

## How it works

The plugin bundles `lib/bash-compat.nu` (adapted from [sv222/bash-for-windows](https://github.com/sv222/bash-for-windows)'s `config.nu`, with deprecation fixes and no startup banner) and executes:

```sh
nu --config <bash-compat.nu> -c <command>
```

Explicit `--config` is required because `nu -c` (non-interactive) does not load the default `config.nu` aliases.

## License

MIT. Bash compatibility layer adapted from [sv222/bash-for-windows](https://github.com/sv222/bash-for-windows) (MIT).
