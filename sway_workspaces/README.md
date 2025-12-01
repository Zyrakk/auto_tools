# Sway Workspaces Auto-Configuration

Automated workspace configuration system for Sway window manager with predefined layouts.

## Overview

7 pre-configured workspaces with automatic initialization:

- **WS1**: 3 terminals (2 horizontal + 1 vertical)
- **WS2**: Development environment (terminal + browser split)
- **WS3**: SSH connections (3 vertical columns)
- **WS4**: Documentation workspace (empty)
- **WS5**: Landing workspace (default, empty)
- **WS8**: Multimedia (Spotify auto-start)
- **WS9**: Gaming (empty)

## Installation

```bash
chmod +x install.sh
./install.sh
```

The installer will:
- Copy scripts to `~/.config/sway/scripts/`
- Copy configs to `~/.config/sway/config.d/`
- Set proper permissions
- Reload Sway configuration

## Files

```
init-workspaces.sh       # Main initialization script
ssh-connect.sh           # SSH server selector with wofi
autostart                # Sway autostart configuration
workspace-keybindings    # Custom keybindings
workspaces               # Workspace definitions
install.sh               # Automated installer
```

## Requirements

**Required:**
- sway
- kitty
- firefox
- wofi
- mako

**Optional:**
- spotify (for WS8)
- obsidian (for WS4)
- steam (for WS9)

## Keybindings

| Key | Action |
|-----|--------|
| `Super+1-9` | Switch to workspace |
| `Super+Shift+1-9` | Move window to workspace |
| `Super+Alt+1-9` | Move window and follow |
| `Super+Ctrl+R` | Reinitialize workspaces |
| `Super+Ctrl+3` | SSH selector |

## SSH Configuration

Edit `~/.config/sway/scripts/ssh-connect.sh`:

```bash
SERVERS=(
    "Server Name|user@host|port"
)
```

## Manual Installation

```bash
# Create directories
mkdir -p ~/.config/sway/{scripts,config.d}

# Copy scripts
cp init-workspaces.sh ssh-connect.sh ~/.config/sway/scripts/
chmod +x ~/.config/sway/scripts/*.sh

# Copy configs
cp autostart workspace-keybindings workspaces ~/.config/sway/config.d/

# Reload Sway
swaymsg reload
```

## Waybar Integration

Add to `~/.config/waybar/config`:
```json
"sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{name}·"
}
```

## Notes

- Firefox and Spotify require 1.5s initialization delay
- Auto-start disabled: comment line in `autostart`
- Landing workspace: WS5 (configurable in `init-workspaces.sh`)
- No automatic window assignments to avoid conflicts

