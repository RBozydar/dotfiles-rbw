# Catppuccin Tmux Custom Modules - Solution Guide

## Problem Summary

Adding custom status bar modules (memory, GPU load, VRAM) with shell commands to catppuccin/tmux that actually display dynamic values instead of raw code.

## The Core Issue

**tmux's `#{E:...}` expansion does NOT execute shell commands.**

When you use catppuccin's pattern:
```tmux
set -g @catppuccin_memory_text "#(free | awk ...)"
set -g status-right "#{E:@catppuccin_status_memory}"
```

The `#{E:...}` expands the variable, but the resulting `#(...)` shell command is treated as **literal text**, not executed.

## What We Tried (and failed)

1. **`#{l:...}` lazy evaluation wrapper** - Catppuccin uses this internally, but it still doesn't execute shell commands after `#{E:...}` expansion.

2. **Escaping with `\}` for awk braces** - Necessary for tmux parsing but doesn't solve the execution issue.

3. **Sourcing catppuccin's `status_module.conf`** - Creates properly styled variables, but shell commands still don't execute.

4. **`%hidden MODULE_NAME` templating** - Works for variable names but requires `source -F` and doesn't solve shell execution.

5. **Using `-F` flag variations** - Tried `-gF`, `-agF`, splitting into multiple `set` commands. None worked.

## What Actually Works

**Embed shell commands directly in `status-right`, not via variable expansion.**

```tmux
# This DOES NOT work - shell command becomes literal text
set -g status-right "#{E:@catppuccin_status_memory}"

# This WORKS - shell command executes
set -ag status-right "#(free | awk '/Mem:/ {printf \"%.0f%%\", \$3/\$2*100}')"
```

## Working Solution

### Catppuccin Theme Colors (Mocha)

| Color | Hex | Use |
|-------|-----|-----|
| blue | #89b4fa | Memory |
| green | #a6e3a1 | GPU Load |
| mauve | #cba6f7 | VRAM |
| flamingo | #f2cdcd | Time |
| crust | #11111b | Icon foreground |
| surface_0 | #313244 | Text background |
| fg | #cdd6f4 | Text foreground |

### Rounded Separators

Catppuccin uses powerline/nerd font characters for rounded module edges:
- Left separator:  (U+E0B6) - `\xee\x82\xb6`
- Right separator:  (U+E0B4) - `\xee\x82\xb4`

### Status Bar Module Pattern

Each module follows this structure:
```
#[fg=<COLOR>]#[bg=default]<LEFT_SEP>#[fg=#11111b,bg=<COLOR>] <ICON> #[fg=#cdd6f4,bg=#313244] <CONTENT>#[fg=#313244]#[bg=default]<RIGHT_SEP>
```

Breakdown:
- `#[fg=<COLOR>]#[bg=default]` - Set separator color
- `<LEFT_SEP>` - Rounded left separator ( U+E0B6)
- `#[fg=#11111b,bg=<COLOR>]` - Icon styling (dark text on colored bg)
- `<ICON>` - Nerd font icon with trailing space
- `#[fg=#cdd6f4,bg=#313244]` - Text styling (light text on dark bg)
- `<CONTENT>` - The actual value (shell command or format)
- `#[fg=#313244]#[bg=default]` - Set right separator color
- `<RIGHT_SEP>` - Rounded right separator ( U+E0B4)

### Final .tmux.conf Configuration

The separator characters must be actual unicode, not escape sequences. Use `printf` or copy from a working config.

```tmux
# Status bar - using direct shell commands (#{E:...} doesn't execute #(...) after expansion)
set -g status-right "#{E:@catppuccin_status_application}"
set -ag status-right "#{E:@catppuccin_status_session}"
# Memory (blue)
set -ag status-right "#[fg=#89b4fa]#[bg=default]#[fg=#11111b,bg=#89b4fa] 󰍛 #[fg=#cdd6f4,bg=#313244] #(free | awk '/Mem:/ {printf \"%.0f%%\", \$3/\$2*100}')#[fg=#313244]#[bg=default] "
# GPU Load (green)
set -ag status-right "#[fg=#a6e3a1]#[bg=default]#[fg=#11111b,bg=#a6e3a1] 󰢮 #[fg=#cdd6f4,bg=#313244] #(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)%#[fg=#313244]#[bg=default] "
# VRAM (mauve)
set -ag status-right "#[fg=#cba6f7]#[bg=default]#[fg=#11111b,bg=#cba6f7] 󰘚 #[fg=#cdd6f4,bg=#313244] #(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | awk -F', ' '{printf \"%.0f%%\", \$1/\$2*100}')#[fg=#313244]#[bg=default] "
# Time (flamingo)
set -ag status-right "#[fg=#f2cdcd]#[bg=default]#[fg=#11111b,bg=#f2cdcd] 󰥔 #[fg=#cdd6f4,bg=#313244] %H:%M#[fg=#313244]#[bg=default] "
```

**Note:** The  and  characters above are the actual unicode separators. If copying doesn't work, insert them using:
```bash
printf '\xee\x82\xb6'  # Left separator
printf '\xee\x82\xb4'  # Right separator
```

### Shell Commands Reference

| Module | Command |
|--------|---------|
| Memory % | `free \| awk '/Mem:/ {printf "%.0f%%", $3/$2*100}'` |
| GPU Load % | `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \| head -1` |
| VRAM % | `nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null \| head -1 \| awk -F', ' '{printf "%.0f%%", $1/$2*100}'` |

### Escaping Rules

When embedding shell commands in tmux config (double-quoted strings):
- `$1`, `$2` etc → `\$1`, `\$2` (escape dollar signs in awk)
- `%%` for literal percent in printf
- Single quotes inside awk are fine
- Pipes `|` don't need escaping

## Why Catppuccin's Built-in CPU Module Works

The `tmux-cpu` plugin uses a **string replacement** approach:
1. It reads `status-right` value
2. Finds `#{cpu_percentage}` literally in the string
3. Replaces it with `#(~/.tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh)`
4. Sets `status-right` back with the replacement

This works because the shell command ends up **directly** in `status-right`, not inside a variable that gets expanded later.

## Key Takeaways

1. **`#{E:@variable}` expands variables but doesn't execute resulting shell commands**
2. **Shell commands must be directly in `status-right`/`status-left` to execute**
3. **Catppuccin's module system works for static content and tmux format strings, not dynamic shell commands**
4. **For custom modules with shell commands, bypass the variable system entirely**
5. **Match catppuccin styling manually using the theme color hex values**
6. **Built-in modules that "work" (like CPU) rely on plugins that do string replacement**

## Useful Commands for Debugging

```bash
# Check what's stored in a variable
tmux show-options -gv @catppuccin_memory_text

# Check what a variable expands to (but won't execute shell commands)
tmux display-message -p '#{E:@catppuccin_status_memory}'

# Test shell command directly in terminal
free | awk '/Mem:/ {printf "%.0f%%", $3/$2*100}'

# Get theme colors
tmux show-options -gv @thm_blue

# Check current status-right value
tmux show-options -g status-right

# Reload config
tmux source-file ~/.tmux.conf

# Test a simple shell command works at all
tmux set -g status-right '#(echo "hello")'
```

### Icons Used

| Module | Icon | Unicode |
|--------|------|---------|
| Memory | 󰍛 | U+F035B |
| GPU Load | 󰢮 | U+F08AE |
| VRAM | 󰘚 | U+F061A |
| Time | 󰥔 | U+F0954 |

## Files

- `~/.tmux.conf` - Main config with direct shell commands in status-right
- `~/repo/dotfiles/docs/CUSTOM_MODULES_NOTES.md` - This documentation
