# dsh-tool-nu

**Model-facing Nushell tool for DeepSeek Harness — 100% bash compatibility on Windows without WSL/Git Bash.**

Registers a `nu` tool for every agent in the profile. Each call runs a fresh Nushell that loads the [bash-for-windows](https://github.com/sv222/bash-for-windows) compatibility layer, so all your favorite bash commands work exactly as on Linux/macOS.

## Why

- DSH's native `bash` tool is disabled on Windows (needs WSL).
- `pwsh` is slow to start and lacks bash muscle memory.
- This plugin gives agents a fast, native, bash-compatible shell backed by [Nushell](https://nushell.sh).

## Features

- `ll`, `la`, `l`, `lh`, `lt`, `ltr`, `lsd`, `lsf` — enhanced listings
- `grep`, `grepi` — pattern search with case options
- `head`, `tail`, `wc`, `uniq`, `sort`, `cut` — text processing
- `ps`, `psg`, `psk`, `top`, `free`, `uptime`, `whoami` — system management
- `kill-by-name`, `kill-by-port` — process termination
- `g`, `gs`, `ga`, `gc`, `gco`, `gd`, `gl`, `gp`, `gpl`, `gb`, `gba`, `gr` — git shortcuts
- `zip`, `unzip` — archives
- `..`, `...`, `....` — quick navigation

## Install

```sh
# from GitHub
dsh plugin --profile web add github:lilyco-42/dsh-tool-nu

# or from a local checkout
dsh plugin --profile web add /path/to/dsh-tool-nu
```

Restart `dsh web`. The `nu` tool appears in every agent's catalog.

## Requirements

- [Nushell](https://nushell.sh) 0.114+ in PATH (e.g. `winget install nushell`, scoop, or chocolatey)
- DeepSeek Harness 0.1.0-rc.6+

## How it works

The plugin bundles `lib/bash-compat.nu` (adapted from [sv222/bash-for-windows](https://github.com/sv222/bash-for-windows)'s `config.nu`, with deprecation fixes and no startup banner) and executes:

```sh
nu --config <bash-compat.nu> -c <command>
```

Explicit `--config` is required because `nu -c` (non-interactive) does not load the default `config.nu` aliases.

## Tool parameters

| Param | Description |
|---|---|
| `command` | The bash-compatible Nushell command to execute |
| `description` | One-line purpose of the command |
| `timeoutMs` | Timeout (default 120s, cap 600s) |
| `workdir` | Working directory, default session workspace |
| `run_in_background` | Background execution returning a job id |
| `sandbox_permissions` / `justification` | Sandbox escalation when configured |

## License

MIT. Bash compatibility layer adapted from [sv222/bash-for-windows](https://github.com/sv222/bash-for-windows) (MIT).
