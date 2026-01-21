# waystt NixOS Integration PRD

## Overview

Install and configure **waystt** (Wayland Speech-to-Text) on NixOS with Waybar status integration and Rofi-based visual feedback. waystt is a signal-driven, composable STT tool that follows Unix philosophy—it outputs transcribed text to stdout for piping to other tools.

### Goals

- Declaratively package waystt using Nix flakes
- Integrate with Waybar for recording status indication
- Provide Rofi-based visual feedback during recording
- Support both local Whisper and cloud API backends
- Configure compositor keybindings (Niri/Hyprland)
- Multilingual support (English/Spanish) with auto-detection
- Leverage AMD 780M iGPU via Vulkan for acceleration

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Workflow                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   [Keybind] ──► [Rofi Popup] ──► [waystt] ──► [Output]         │
│       │              │               │            │             │
│   Super+R      "Recording..."   Transcribe   ydotool/wl-copy   │
│       │              │               │            │             │
│       └──────────────┴───────────────┴────────────┘             │
│                           │                                     │
│                    [Waybar Module]                              │
│                    Shows 🎤 when active                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. waystt Package

waystt is not in nixpkgs. Package it as a Rust binary using `buildRustPackage`.

#### Package Definition (`packages/waystt/default.nix`)

```nix
{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, alsa-lib
, pipewire
, vulkan-loader
, vulkan-headers
}:

rustPlatform.buildRustPackage rec {
  pname = "waystt";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "sevos";
    repo = "waystt";
    rev = "v${version}";
    hash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"; # Update after fetching
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    # If there are git dependencies, add outputHashes here
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
    alsa-lib
    pipewire
    vulkan-loader
    vulkan-headers
  ];

  # Enable Vulkan backend for GPU acceleration
  WHISPER_VULKAN = "1";

  meta = with lib; {
    description = "Minimal signal-driven speech-to-text for Wayland";
    homepage = "https://github.com/sevos/waystt";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
```

#### Flake Input (in `flake.nix`)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Option A: Package locally (recommended)
    # Just add the package to your overlay
    
    # Option B: If upstream adds a flake
    # waystt.url = "github:sevos/waystt";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # Add waystt to your packages overlay
    overlays.default = final: prev: {
      waystt = final.callPackage ./packages/waystt { };
    };
  };
}
```

### 2. System Dependencies

Add to your NixOS configuration:

```nix
{ pkgs, ... }:

{
  # AMD GPU / Vulkan support (for Whisper acceleration)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      amdvlk           # AMD Vulkan driver
      vulkan-loader
      vulkan-tools     # vulkaninfo for debugging
    ];
  };

  # Required services
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ydotool for direct typing
  programs.ydotool.enable = true;
  
  # Or manually:
  # services.ydotool.enable = true;
  # users.users.dustin.extraGroups = [ "input" ];

  # System packages
  environment.systemPackages = with pkgs; [
    wl-clipboard    # wl-copy for clipboard output
    libnotify       # notify-send for notifications
    rofi-wayland    # Rofi for visual feedback
  ];
}
```

### 3. Home Manager Configuration

#### Main Module (`home/modules/waystt.nix`)

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.waystt;
in {
  options.services.waystt = {
    enable = mkEnableOption "waystt speech-to-text";

    package = mkOption {
      type = types.package;
      default = pkgs.waystt;
      description = "The waystt package to use";
    };

    provider = mkOption {
      type = types.enum [ "openai" "google" "local" ];
      default = "local";
      description = "Transcription provider";
    };

    model = mkOption {
      type = types.str;
      default = "ggml-medium.bin";
      description = "Whisper model for local transcription (use non-.en for multilingual)";
    };

    language = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Force specific language (null for auto-detect)";
    };

    audioFeedback = mkOption {
      type = types.bool;
      default = true;
      description = "Enable audio beeps for recording start/stop";
    };

    beepVolume = mkOption {
      type = types.float;
      default = 0.1;
      description = "Volume for audio feedback (0.0-1.0)";
    };

    openaiApiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing OpenAI API key";
    };

    googleCredentialsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to Google service account JSON";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Configuration file
    xdg.configFile."waystt/.env".text = ''
      TRANSCRIPTION_PROVIDER=${cfg.provider}
      ${optionalString (cfg.provider == "local") "WHISPER_MODEL=${cfg.model}"}
      ${optionalString (cfg.language != null) "WHISPER_LANGUAGE=${cfg.language}"}
      ENABLE_AUDIO_FEEDBACK=${boolToString cfg.audioFeedback}
      BEEP_VOLUME=${toString cfg.beepVolume}
      ${optionalString (cfg.openaiApiKeyFile != null) "OPENAI_API_KEY=$(cat ${cfg.openaiApiKeyFile})"}
      ${optionalString (cfg.googleCredentialsFile != null) "GOOGLE_APPLICATION_CREDENTIALS=${cfg.googleCredentialsFile}"}
    '';

    # Download model on activation (for local provider)
    home.activation.downloadWhisperModel = mkIf (cfg.provider == "local") (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        MODEL_DIR="$HOME/.local/share/applications/waystt/models"
        MODEL_FILE="$MODEL_DIR/${cfg.model}"
        if [ ! -f "$MODEL_FILE" ]; then
          $DRY_RUN_CMD mkdir -p "$MODEL_DIR"
          $DRY_RUN_CMD ${cfg.package}/bin/waystt --download-model || true
        fi
      ''
    );
  };
}
```

#### Usage in Home Configuration

```nix
{ config, pkgs, ... }:

{
  imports = [ ./modules/waystt.nix ];

  services.waystt = {
    enable = true;
    provider = "local";
    model = "ggml-medium.bin";  # Multilingual (en/es) - good balance
    # model = "ggml-small.bin"; # Faster, still multilingual
    # model = "ggml-large-v3.bin"; # Best accuracy, slower
    language = null;  # Auto-detect between English/Spanish
    audioFeedback = true;
    beepVolume = 0.1;
    
    # For cloud providers:
    # provider = "openai";
    # openaiApiKeyFile = config.sops.secrets.openai-api-key.path;
  };
}
```

### 4. Waybar Integration

#### Module Configuration (`home/waybar/config.jsonc`)

```jsonc
{
  "modules-right": [
    "custom/stt",
    // ... other modules
  ],

  "custom/stt": {
    "exec": "~/.config/waybar/scripts/stt-status.sh",
    "return-type": "json",
    "interval": 1,
    "on-click": "pkill --signal SIGUSR1 waystt || true",
    "tooltip": true
  }
}
```

#### Status Script (`home/waybar/scripts/stt-status.sh`)

```bash
#!/usr/bin/env bash

# Check if waystt is running and in recording state
if pgrep -x waystt > /dev/null; then
    # Check if actively recording (existence of temp audio file)
    if [ -f /tmp/waystt-recording ]; then
        echo '{"text": "🎤", "class": "recording", "tooltip": "Recording... (click to stop)"}'
    else
        echo '{"text": "🎙️", "class": "ready", "tooltip": "STT ready (click to transcribe)"}'
    fi
else
    echo '{"text": "", "class": "inactive", "tooltip": "STT inactive"}'
fi
```

#### Waybar Styles (`home/waybar/style.css`)

```css
#custom-stt {
    padding: 0 10px;
    margin: 0 4px;
}

#custom-stt.recording {
    color: #f38ba8;
    animation: pulse 1s ease-in-out infinite;
}

#custom-stt.ready {
    color: #a6e3a1;
}

#custom-stt.inactive {
    color: transparent;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}
```

#### Home Manager Waybar Module

```nix
{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    settings = [{
      modules-right = [ "custom/stt" /* ... */ ];
      
      "custom/stt" = {
        exec = "${config.xdg.configHome}/waybar/scripts/stt-status.sh";
        return-type = "json";
        interval = 1;
        on-click = "pkill --signal SIGUSR1 waystt || true";
        tooltip = true;
      };
    }];
    
    style = builtins.readFile ./waybar/style.css;
  };

  xdg.configFile."waybar/scripts/stt-status.sh" = {
    source = ./waybar/scripts/stt-status.sh;
    executable = true;
  };
}
```

### 5. Rofi Integration

#### Recording Toggle Script (`home/scripts/stt-toggle.sh`)

```bash
#!/usr/bin/env bash
# stt-toggle.sh - Toggle waystt with Rofi visual feedback

set -euo pipefail

LOCK_FILE="/tmp/waystt-recording"
ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/stt.rasi"

start_recording() {
    touch "$LOCK_FILE"
    
    # Start waystt in background, piping to chosen output
    case "${1:-type}" in
        type)
            waystt --pipe-to "ydotool type --file -" &
            ;;
        clipboard)
            waystt --pipe-to wl-copy &
            ;;
    esac
    
    WAYSTT_PID=$!
    
    # Show Rofi and wait for dismissal
    echo -e "Stop Recording\nCancel" | rofi -dmenu \
        -p "🎤 Recording" \
        -theme "$ROFI_THEME" \
        -selected-row 0 \
        -kb-accept-entry "Return" \
        -kb-cancel "Escape" 2>/dev/null || true
    
    # Send transcribe signal
    pkill --signal SIGUSR1 waystt 2>/dev/null || true
    
    rm -f "$LOCK_FILE"
    
    # Notify completion
    notify-send -t 2000 "STT" "Transcription complete"
}

stop_recording() {
    pkill --signal SIGUSR1 waystt 2>/dev/null || true
    rm -f "$LOCK_FILE"
}

# Main logic
if pgrep -x waystt > /dev/null; then
    stop_recording
else
    start_recording "${1:-type}"
fi
```

#### Rofi Theme for STT (`home/rofi/stt.rasi`)

```css
/* STT Recording Popup */
@import "colors.rasi"

configuration {
    show-icons: false;
    font: "JetBrainsMono Nerd Font 14";
}

window {
    width: 300px;
    location: center;
    anchor: center;
    border-radius: 12px;
    border: 2px solid;
    border-color: @accent;
    background-color: @background;
}

mainbox {
    background-color: transparent;
    children: [ inputbar, listview ];
}

inputbar {
    padding: 16px;
    background-color: @accent;
    text-color: @background;
    children: [ prompt ];
}

prompt {
    background-color: transparent;
    text-color: inherit;
}

listview {
    lines: 2;
    padding: 8px;
    background-color: transparent;
}

element {
    padding: 12px;
    border-radius: 6px;
    background-color: transparent;
    text-color: @foreground;
}

element selected {
    background-color: @accent;
    text-color: @background;
}
```

#### Home Manager Script Installation

```nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    rofi-wayland
    libnotify
  ];

  xdg.configFile = {
    "rofi/stt.rasi".source = ./rofi/stt.rasi;
  };

  home.file.".local/bin/stt-toggle" = {
    source = ./scripts/stt-toggle.sh;
    executable = true;
  };
}
```

### 6. Compositor Keybindings

#### Niri Configuration

```kdl
binds {
    // STT - Direct typing (most common)
    Mod+R { spawn "sh" "-c" "~/.local/bin/stt-toggle type"; }
    
    // STT - Clipboard copy
    Mod+Shift+R { spawn "sh" "-c" "~/.local/bin/stt-toggle clipboard"; }
}
```

#### Hyprland Configuration

```conf
# STT - Direct typing
bind = SUPER, R, exec, ~/.local/bin/stt-toggle type

# STT - Clipboard copy
bind = SUPER SHIFT, R, exec, ~/.local/bin/stt-toggle clipboard
```

#### Home Manager for Niri

```nix
{ config, ... }:

{
  xdg.configFile."niri/config.kdl".text = ''
    binds {
        Mod+R { spawn "sh" "-c" "${config.home.homeDirectory}/.local/bin/stt-toggle type"; }
        Mod+Shift+R { spawn "sh" "-c" "${config.home.homeDirectory}/.local/bin/stt-toggle clipboard"; }
    }
  '';
}
```

---

## Implementation Checklist

### Phase 1: Core Package
- [ ] Create `packages/waystt/default.nix`
- [ ] Add to flake overlay
- [ ] Verify build with `nix build .#waystt`
- [ ] Get correct source hash

### Phase 2: System Configuration
- [ ] Enable PipeWire
- [ ] Enable ydotool service
- [ ] Add user to `input` group
- [ ] Install wl-clipboard, libnotify, rofi-wayland

### Phase 3: Home Manager Module
- [ ] Create `home/modules/waystt.nix`
- [ ] Configure provider and model
- [ ] Test manual waystt execution

### Phase 4: Integration Scripts
- [ ] Create `stt-toggle.sh`
- [ ] Create `stt-status.sh`
- [ ] Create Rofi theme
- [ ] Test scripts manually

### Phase 5: Waybar Integration
- [ ] Add custom/stt module
- [ ] Add CSS styles
- [ ] Verify status updates

### Phase 6: Compositor Keybindings
- [ ] Add Niri/Hyprland bindings
- [ ] Test full workflow

### Phase 7: Polish
- [ ] Download and test Whisper models
- [ ] Tune beep volume
- [ ] Test multilingual (en/es)
- [ ] Document any quirks

---

## Configuration Reference

### Hardware Notes (AMD Ryzen 9 7940HS + Radeon 780M)

Your integrated 780M GPU supports Vulkan acceleration for whisper.cpp. With Vulkan enabled:
- `ggml-medium.bin` runs in ~2-3 seconds for typical utterances
- `ggml-small.bin` runs sub-second
- Much faster than CPU-only inference

Verify Vulkan is working:
```bash
vulkaninfo | grep "GPU id"
# Should show: AMD Radeon 780M Graphics
```

### Whisper Models (Local Provider)

| Model | Size | Speed (780M) | Accuracy | Languages |
|-------|------|--------------|----------|-----------|
| `ggml-tiny.bin` | 39 MB | ~0.3s | Lower | Multilingual |
| `ggml-tiny.en.bin` | 39 MB | ~0.3s | Lower | English only |
| `ggml-base.bin` | 142 MB | ~0.5s | Good | Multilingual |
| `ggml-base.en.bin` | 142 MB | ~0.5s | Good | English only |
| `ggml-small.bin` | 466 MB | ~1s | Better | Multilingual |
| `ggml-small.en.bin` | 466 MB | ~1s | Better | English only |
| `ggml-medium.bin` | 1.5 GB | ~2-3s | High | **Recommended (en/es)** |
| `ggml-medium.en.bin` | 1.5 GB | ~2-3s | High | English only |
| `ggml-large-v3.bin` | 2.9 GB | ~5s | Best | Multilingual |

**Recommendations for English + Spanish:**
- **Daily use:** `ggml-medium.bin` — best balance of speed and accuracy for bilingual
- **Quick notes:** `ggml-small.bin` — faster, still good multilingual support
- **Maximum accuracy:** `ggml-large-v3.bin` — when accuracy matters more than speed

**Note:** `.en.bin` models are English-only. For Spanish support, use the non-`.en` variants.

### Signal Reference

| Signal | Effect |
|--------|--------|
| `SIGUSR1` | Toggle recording / trigger transcription |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TRANSCRIPTION_PROVIDER` | `openai` | `openai`, `google`, or `local` |
| `WHISPER_MODEL` | `whisper-1` | Model name (varies by provider) |
| `WHISPER_LANGUAGE` | auto | ISO language code (`en`, `es`) or null for auto-detect |
| `ENABLE_AUDIO_FEEDBACK` | `true` | Beep on start/stop |
| `BEEP_VOLUME` | `0.5` | 0.0 to 1.0 |
| `OPENAI_API_KEY` | — | Required for OpenAI provider |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | Path to JSON for Google |

### Language Auto-Detection

With `WHISPER_LANGUAGE` unset (null), Whisper auto-detects the spoken language per utterance. This works well for:
- Switching between English and Spanish naturally
- Mixed-language conversations
- Code-switching mid-sentence (accuracy varies)

To force a specific language (slightly faster, avoids misdetection):
```bash
WHISPER_LANGUAGE=en  # English only
WHISPER_LANGUAGE=es  # Spanish only
```

---

## Troubleshooting

### Vulkan/GPU not being used
```bash
# Verify Vulkan driver is loaded
vulkaninfo | grep "GPU id"
# Should show: AMD Radeon 780M Graphics

# Check AMD driver
lsmod | grep amdgpu
# Should show amdgpu module loaded

# If missing, ensure hardware.graphics is configured
```

### waystt won't start
```bash
# Check PipeWire is running
systemctl --user status pipewire

# Verify microphone
pactl list sources short
```

### ydotool not typing
```bash
# Check service
systemctl --user status ydotool

# Verify group membership
groups | grep input

# Test directly
echo "test" | ydotool type --file -
```

### Model download fails
```bash
# Manual download (multilingual medium model)
mkdir -p ~/.local/share/applications/waystt/models
cd ~/.local/share/applications/waystt/models
wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin

# Or for faster/smaller multilingual:
wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin
```

### Rofi not showing
```bash
# Test Rofi directly
echo "Test" | rofi -dmenu -p "STT"

# Check theme path
ls ~/.config/rofi/stt.rasi
```

---

## Future Enhancements

- [ ] Systemd user service for persistent waystt daemon
- [ ] AGS/EWW widget as Waybar alternative  
- [ ] Voice activity detection (VAD) for hands-free operation
- [ ] Custom word replacements/corrections
- [ ] Integration with Claude Code for voice-driven development
