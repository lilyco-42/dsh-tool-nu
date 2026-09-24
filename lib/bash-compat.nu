# Nushell Configuration with Bash Compatibility Aliases for Windows 11
# Based on official Nushell documentation: https://www.nushell.sh/book/

# Basic configuration
$env.config = ($env.config | default {} | merge {
    show_banner: false
})

# ============================================================================
# FILE AND DIRECTORY OPERATIONS
# ============================================================================

# Common ls aliases
alias ll = ls -l
alias la = ls -la
alias l = ls -la
alias lh = ls -la
def lt [] { ls -l | sort-by modified }
def ltr [] { ls -l | sort-by modified | reverse }
def lsd [] { ls | where type == dir }
def lsf [] { ls | where type == file }

# Directory navigation shortcuts
alias .. = cd ..
alias ... = cd ../..
alias .... = cd ../../..
alias ..... = cd ../../../..

# Directory operations
alias md = mkdir
alias rd = rmdir

# File operations
alias cp = cp
alias mv = mv
alias rm = rm
alias ln = ln

# ============================================================================
# TEXT PROCESSING COMMANDS
# ============================================================================

# Grep equivalents
def grep [pattern: string, ...files: string] {
    if ($files | is-empty) {
        $in | lines | where ($it | str contains $pattern)
    } else {
        $files | each { |file|
            open $file | lines | where ($it | str contains $pattern) | each { |line| $"($file):($line)" }
        } | flatten
    }
}

def grepi [pattern: string, ...files: string] {
    if ($files | is-empty) {
        $in | lines | where ($it | str lowercase | str contains ($pattern | str lowercase))
    } else {
        $files | each { |file|
            open $file | lines | where ($it | str lowercase | str contains ($pattern | str lowercase)) | each { |line| $"($file):($line)" }
        } | flatten
    }
}

# Head and tail equivalents.
# Accepts every bash/POSIX spelling: `head 5`, `head -5`, `head -n 5`, `head --lines 5`.
# Input may be a list/table/range OR text piped out of an external command. The type
# dispatch is required: a bare `first`/`last` refuses text input and dies with
# `only_supports_this_input_type`, which made `^cat file | head 3` unusable.
def head [
    count: int = 10,        # `head 5` or `head -5`
    --lines(-n): int,       # `head -n 5` or `head --lines 5`
] {
    let requested = (if ($lines | is-empty) { $count } else { $lines })
    # `0 - $requested`, NOT `-$requested`: nushell parses a bare `-$var` as the *string*
    # literal "-$requested", which then blows up inside `first`/`last` as a type mismatch.
    let k = (if $requested < 0 { 0 - $requested } else { $requested })
    let input = $in
    let kind = ($input | describe)
    if ($kind | str starts-with "list") or ($kind | str starts-with "table") or ($kind | str starts-with "range") {
        $input | first $k
    } else {
        $input | lines | first $k
    }
}

def tail [
    count: int = 10,        # `tail 5` or `tail -5`
    --lines(-n): int,       # `tail -n 5` or `tail --lines 5`
] {
    let requested = (if ($lines | is-empty) { $count } else { $lines })
    let k = (if $requested < 0 { 0 - $requested } else { $requested })
    let input = $in
    let kind = ($input | describe)
    if ($kind | str starts-with "list") or ($kind | str starts-with "table") or ($kind | str starts-with "range") {
        $input | last $k
    } else {
        $input | lines | last $k
    }
}

# Wc equivalent.
#   ... | wc        -> {lines: N, words: N, chars: N}
#   ... | wc -l     -> line count as a plain number, so `... | wc -l` composes
#   ... | wc -w     -> word count
#   ... | wc -c     -> character count
# Same type dispatch as head/tail, so it also works on external command output.
def wc [
    --lines(-l),        # print only the line count
    --words(-w),        # print only the word count
    --chars(-c),        # print only the character count
] {
    let input = $in
    let kind = ($input | describe)
    let text = (if ($kind | str starts-with "list") or ($kind | str starts-with "table") {
        $input | each {|row| $row | into string } | str join "\n"
    } else {
        $input | into string
    })
    let n_lines = ($text | lines | length)
    let n_words = ($text | split words | length)
    let n_chars = ($text | str length)
    if $lines {
        $n_lines
    } else if $words {
        $n_words
    } else if $chars {
        $n_chars
    } else {
        {lines: $n_lines, words: $n_words, chars: $n_chars}
    }
}

# Sort equivalents
# Built-in sort command available
def sort-reverse [] { $in | sort | reverse }
def sort-numeric [] { $in | sort-by {|x| $x | into int} }

# Uniq equivalent — bash semantics: only *adjacent* duplicates are collapsed.
#   ... | uniq        -> drop adjacent duplicates
#   ... | uniq -c     -> "COUNT ITEM" per run
#   ... | uniq -d     -> only items whose run length is > 1
#   ... | uniq -u     -> only items whose run length is == 1
#   ... | uniq -i     -> compare case-insensitively
# Accepts list/table/range input and text from external commands.
# DO NOT "simplify" this back to `def uniq [] { $in | uniq }`: `def` shadows the
# nushell builtin, so the body calls itself and dies with
# `nu::shell::recursion_limit_reached`. (That was the original bug here.)
def uniq [
    --count(-c),        # prefix each line with its number of occurrences
    --repeated(-d),     # only print duplicated runs
    --unique(-u),       # only print non-duplicated runs
    --ignore-case(-i),  # compare case-insensitively
] {
    let input = $in
    let kind = ($input | describe)
    let rows = (if ($kind | str starts-with "list") or ($kind | str starts-with "table") {
        $input
    } else {
        $input | lines
    })
    # Fold the rows into runs: extend the current run, or start a new one.
    let groups = ($rows | reduce --fold [] {|row, acc|
        let key = (if $ignore_case { $row | into string | str lowercase } else { $row | into string })
        if ($acc | is-empty) {
            [{key: $key, item: $row, count: 1}]
        } else if (($acc | last).key == $key) {
            let prev = ($acc | last)
            ($acc | take (($acc | length) - 1)) | append {key: $key, item: $prev.item, count: ($prev.count + 1)}
        } else {
            $acc | append {key: $key, item: $row, count: 1}
        }
    })
    let picked = (
        if $repeated {
            $groups | where count > 1
        } else if $unique {
            $groups | where count == 1
        } else {
            $groups
        }
    )
    if $count {
        $picked | each {|g| $"($g.count) ($g.item)" }
    } else {
        $picked | each {|g| $g.item }
    }
}

# Cut equivalent
def cut [delimiter: string, field: int] {
    $in | lines | each { |line| $line | split row $delimiter | get ($field - 1) }
}

# ============================================================================
# SYSTEM MONITORING AND PROCESS MANAGEMENT
# ============================================================================

# Process management
alias ps = ps
def psg [pattern: string] { ps | where name =~ $pattern }
def psk [pattern: string] { ps | where name =~ $pattern | each { |proc| kill $proc.pid } }

# System information (Windows compatible)
# `sys` on its own returns a formatted *string* in Nushell 0.11x, so
# `sys | get <field>` fails with only_supports_this_input_type. The structured
# data lives in the sub-tables: sys host / sys mem / sys cpu / sys disks.
def free [] { sys mem }
def uptime [] { sys host | get uptime }
def whoami [] { $env.USERNAME }

# Process monitoring (Windows compatible)
# Use Task Manager: taskmgr
# Use PowerShell: Get-Process
def top [] { ps | sort-by cpu | reverse }

# ============================================================================
# NETWORK UTILITIES
# ============================================================================

# Network commands (Windows compatible)
alias ping = ^ping
# Note: wget, curl available via winget or chocolatey
# alias curl = ^curl
# SSH available in Windows 10/11
# alias ssh = ^ssh

# ============================================================================
# ARCHIVE AND COMPRESSION
# ============================================================================

# Archive operations (Windows compatible)
# Use built-in Compress-Archive / Expand-Archive
def zip [source: string, dest: string] { ^powershell -Command $"Compress-Archive '($source)' '($dest)'" }
def unzip [source: string, dest?: string] {
    let destination = if ($dest | is-empty) { "." } else { $dest }
    ^powershell -Command $"Expand-Archive '($source)' '($destination)'"
}

# ============================================================================
# GIT WORKFLOW ALIASES
# ============================================================================

# Git shortcuts
alias g = git
alias gs = git status
alias gst = git status -sb
alias ga = git add
alias gaa = git add -A
alias gc = git commit
alias gcm = git commit -m
alias gco = git checkout
alias gb = git branch
alias gba = git branch -a
alias gd = git diff
alias gds = git diff --staged
alias gl = git log --oneline
alias gll = git log --oneline --graph --all
alias gp = git push
alias gpu = git push -u origin
alias gpl = git pull
alias gf = git fetch
alias gr = git remote -v
alias grs = git reset
alias grh = git reset --hard

# ============================================================================
# ENVIRONMENT AND SHELL CONFIGURATION
# ============================================================================

# Environment shortcuts.
def env [] { $env | table }
# Nushell runs a `def` body in a child scope, so a function CANNOT change the
# caller's environment. These three used to look like they worked while
# silently doing nothing (measured: `setenv FOO bar` left the variable unset,
# `path-add` left PATH unchanged). They now fail loudly instead of lying.
def setenv [name: string, value: string] {
    error make {msg: $"setenv is not possible in Nushell: a function cannot modify the caller's environment. Assign the variable at the call site instead. Requested name: ($name)"}
}
def unsetenv [name: string] {
    error make {msg: $"unsetenv is not possible in Nushell: a function cannot modify the caller's environment. Hide the variable at the call site instead. Requested name: ($name)"}
}

# Path operations
def path-add [path: string] {
    error make {msg: $"path-add is not possible in Nushell: a function cannot modify the caller's PATH. Prepend to the PATH variable at the call site instead. Requested path: ($path)"}
}

def path-show [] {
    $env.PATH | each { |p| echo $p }
}

# ============================================================================
# HISTORY AND NAVIGATION
# ============================================================================

# History shortcuts
alias h = history
def hg [pattern: string] { history | where command =~ $pattern }

# Quick navigation (Windows compatible)
def home [] { cd $env.USERPROFILE }
def root [] { cd C:\ }

# ============================================================================
# EXTERNAL COMMANDS INTEGRATION
# ============================================================================

# Git Bash integration for Windows
$env.PATH = ($env.PATH | prepend 'C:\Program Files\Git\bin')

# Text editors (Windows compatible)
# Note: Install via winget, chocolatey, or use built-in editors
# alias vim = ^vim
# alias nano = ^nano
alias notepad = ^notepad
alias more = ^more
# Use Get-Help instead of man
def man [cmd: string] { help $cmd }

# ============================================================================
# BASH-STYLE SHORTCUTS AND ALIASES
# ============================================================================

# Common bash shortcuts
alias c = clear
alias q = exit
alias x = exit

# File viewing
alias cat = open
def more-file [file: string] { open $file | lines | each { |line| print $line } }

# Quick editing
def edit [file: string] { ^$env.EDITOR $file }

# Disk usage shortcuts
def dus [] { du | sort-by size | reverse }
def dush [] { du --max-depth 0 }

# Find equivalents
def find-name [pattern: string] { ls **/* | where name =~ $pattern }
def find-type [type: string] { ls **/* | where type == $type }

# Windows doesn't use chmod - files are executable by extension
# def chmod-x [file: string] { echo "Windows uses file extensions for execution" }

# ============================================================================
# BASH WORKFLOW COMPATIBILITY
# ============================================================================

# Common bash patterns
def ll-grep [pattern: string] { ls -l | where name =~ $pattern }
def ps-grep [pattern: string] { ps | where name =~ $pattern }

# Pipe to less (Windows: more)
def to-less [] { $in | ^more }

# Count lines/files
def count-lines [] { $in | lines | length }
def count-files [] { ls | length }

# ============================================================================
# ADDITIONAL BASH-STYLE FUNCTIONS
# ============================================================================

# Which command
alias which = which

# Locate files
def locate [pattern: string] { ls **/* | where name =~ $pattern | get name }

# Tree view (available in Windows)
alias tree = ^tree

# Disk space (Windows compatible).
# `wmic` was removed from Windows 11, so use Nushell's own structured disk table.
def disk-free [] {
    sys disks | select mount total free
}

# Memory info
def mem-info [] { sys mem }

# CPU info
def cpu-info [] { sys cpu }

# Load averages (per-CPU, as Nushell reports them)
def load-avg [] { sys cpu | get load_average }

# ============================================================================
# BASH-STYLE COMPLETION AND SHORTCUTS
# ============================================================================

# Quick directory changes for common locations (Windows)
def desktop [] { cd $env.USERPROFILE/Desktop }
def downloads [] { cd $env.USERPROFILE/Downloads }
def documents [] { cd $env.USERPROFILE/Documents }

# Quick config access
def config-nu [] { ^$env.EDITOR $nu.config-path }
# To reload config, restart Nushell or run: nu
def restart-nu [] {
}

# ============================================================================
# ADVANCED BASH COMPATIBILITY
# ============================================================================

# Bash-style command substitution helpers
def cmd-output [cmd: string] { nu -c $cmd }

# File test equivalents
def file-exists [path: string] { $path | path exists }
def dir-exists [path: string] {
    ($path | path exists) and (($path | path type) == "dir")
}
def file-readable [path: string] { try { open $path; true } catch { false } }

# Date and time
# Built-in date command already exists
def timestamp [] { date now | format date "%Y-%m-%d %H:%M:%S" }

# Calendar (Windows compatible)
# Use built-in PowerShell Get-Date
def cal [] { ^powershell -Command "Get-Date" }

# Calculator.
# `math eval` no longer exists in Nushell, and `nu -c "1+2"` treats the text as
# an external command name, so hand the expression to PowerShell instead.
def calc [expr: string] { ^powershell -Command $expr }

# Weather (requires curl - install via winget)
# def weather [city?: string] {
#     let location = if ($city | is-empty) { "" } else { $city }
#     ^curl -s $"wttr.in/($location)"
# }

# System cleanup helpers (Windows compatible)
def clean-temp [] {
    let temp_dir = $env.TEMP
    if ($temp_dir | path exists) {
        ls $temp_dir | each { |item| rm -rf $item.name }
    }
}
def clean-logs [] {
    let logs_dir = ($env.USERPROFILE | path join "AppData" "Local" "Temp")
    if ($logs_dir | path exists) {
        ls $logs_dir | each { |item| rm -rf $item.name }
    }
}

# Process helpers (Windows compatible)
def kill-by-name [name: string] { ps | where name =~ $name | each { |p| kill $p.pid } }
def kill-by-port [port: int] {
    ^netstat -ano | lines | where ($it | str contains $":($port) ") | each { |line|
        let pid = ($line | str trim | split row " " | last)
        if ($pid != "PID") { kill ($pid | into int) }
    }
}

# ============================================================================
# FINAL CONFIGURATION
# ============================================================================

# Source additional configuration files if they exist
# if ($env.USERPROFILE | path join ".nushell" "extra.nu" | path exists) {
#     source ($env.USERPROFILE | path join ".nushell" "extra.nu")
# }


# End of bash-for-windows compatibility layer (adapted for DSH agents)
