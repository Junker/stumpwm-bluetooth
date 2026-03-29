# stumpwm-bluetooth

A StumpWM module for controlling Bluetooth devices via `bluetoothctl`.

## Installation

```bash
cd ~/.stumpwm.d/modules/
git clone https://github.com/Junker/stumpwm-bluetooth bluetooth
```

```lisp
(stumpwm:add-to-load-path "~/.stumpwm.d/modules/bluetooth")
(load-module "wpctl")
```

## Usage

```lisp
  (bluetooth:init) ; to initialize modeline updates
```

## Dependencies

- `bluetoothctl` (usually comes with BlueZ)
- `cl-ppcre` (for regex parsing)
- Optional: `blueman-manager` for GUI (configurable)

## Modeline

Add `%Y` to your mode-line format string:

```lisp
(setf *screen-mode-line-format* '("[%B] %W"))
```

### Formatters

| Formatter | Description |
|-----------|-------------|
| `%p` | Power status (ON/OFF) |
| `%d` | Connected device name |
| `%n` | Number of connected devices |

### Custom Format

```lisp
(setf bluetooth:*modeline-fmt* "%p [%d]")
```

### Modeline Click Actions

| Button | Action |
|--------|--------|
| Left | Toggle power |
| Right | Select device to connect/disconnect |
| Middle | Open bluetooth manager GUI |
| Wheel Up | Connect to paired device |
| Wheel Down | Disconnect from device |

## Commands

| Command | Description |
|---------|-------------|
| `bluetooth-toggle-power` | Toggle bluetooth power on/off |
| `bluetooth-power-on` | Turn bluetooth on |
| `bluetooth-power-off` | Turn bluetooth off |
| `bluetooth-select-device` | Select a paired device to connect/disconnect |
| `bluetooth-connect` | Connect to a paired device |
| `bluetooth-disconnect` | Disconnect from a device |
| `bluetooth-toggle-device` | Toggle device connection |
| `bluetooth-pair` | Pair with a new device |
| `bluetooth-remove` | Remove a paired device |
| `bluetooth-scan` | Scan for new devices (5 seconds) |
| `bluetooth-open-manager` | Open bluetooth manager GUI |


## Configuration Variables

```lisp
;; Path to bluetoothctl (default: "/usr/bin/bluetoothctl")
(defvar bluetooth:*bluetooth-path* "/usr/bin/bluetoothctl")

;; Interval for updating status (default: 5 seconds)
(defvar bluetooth:*check-interval* 3)

;; Bluetooth manager GUI command (default: "blueman-manager")
(defvar bluetooth:*bluetooth-manager-command* "blueman-manager")

;; Modeline format string
(defvar bluetooth:*modeline-fmt* "%p %d")
```

