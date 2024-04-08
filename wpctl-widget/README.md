# Wpctl volume widget

Volume widget that uses `wpctl` for controlling audio volume and selecting sinks and sources.

This widget is heavily based on the pactl and original volume widgets, sharing most of the same customization options. For screenshots, see the original widget.

## Installation

Clone the repo under **~/.config/awesome/** and add widget in **rc.lua**:

```lua
local volume_widget = require('awesome-wm-widgets.wpctl-widget.volume')
...
s.mytasklist, -- Middle widget
	{ -- Right widgets
    	layout = wibox.layout.fixed.horizontal,
        ...
        -- default
        volume_widget(),
        -- customized
        volume_widget{
            widget_type = 'arc'
        },
```

### Shortcuts

To improve responsiveness of the widget when volume level is changed by a shortcut use corresponding methods of the widget:

```lua
awful.key({}, "XF86AudioRaiseVolume", function () volume_widget:inc(5) end),
awful.key({}, "XF86AudioLowerVolume", function () volume_widget:dec(5) end),
awful.key({}, "XF86AudioMute", function () volume_widget:toggle() end),
```

## Customization

It is possible to customize the widget by providing a table with all or some of the following config parameters:

### Generic parameter

| Name | Default | Description |
|---|---|---|
| `mixer_cmd` | `nil` | command to run on middle click (e.g. a mixer program) |
| `step` | 5 | How much the volume is raised or lowered at once (in %) |
| `max_volume` | `nil` | The maximum value the volume can be raised to (in %) |
| `min_volume` | 0 | The minimum value the volume can be raised to (in %) |
| `widget_type`| `icon_and_text`| Widget type, one of `horizontal_bar`, `vertical_bar`, `icon`, `icon_and_text`, `arc` |
| `device` | `@DEFAULT_SINK@` | Select the device name to control |
| `tooltip` | false | Display volume level in a tooltip when the mouse cursor hovers the widget |

For more details on parameters depending on the chosen widget type, please refer to the original Volume widget.

## Differences from the original volume widget and the pactl widget

* Default `mixer_cmd` parameter value is now nil (was `pavucontrol` in original and pactl widgets)
* Customization parameters `toggle_cmd`, `card`, `device`, `mixctrl`, and `value_type` no longer exist as they are only needed by amixer and pacmd
* `min_volume` and `max_volume` parameters added
* This widget switches between pipewire nodes rather than ports, which might make some devices unusable without manual configuration
