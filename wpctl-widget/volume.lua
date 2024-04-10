-------------------------------------------------
-- A wpctl-based volume widget based on the awesome-wm-widgets volume and pactl widgets
-------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local gears = require("gears")
local beautiful = require("beautiful")

local wpctl = require("awesome-wm-widgets.wpctl-widget.wpctl")

local widget_types = {
    icon_and_text = require("awesome-wm-widgets.volume-widget.widgets.icon-and-text-widget"),
    icon = require("awesome-wm-widgets.volume-widget.widgets.icon-widget"),
    arc = require("awesome-wm-widgets.volume-widget.widgets.arc-widget"),
    horizontal_bar = require("awesome-wm-widgets.volume-widget.widgets.horizontal-bar-widget"),
    vertical_bar = require("awesome-wm-widgets.volume-widget.widgets.vertical-bar-widget")
}

local volume = {}

local rows = { layout = wibox.layout.fixed.vertical }

local popup = awful.popup {
    bg = beautiful.bg_normal,
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    border_width = 1,
    border_color = beautiful.bg_focus,
    maximum_width = 400,
    offset = { y = 5 },
    widget = {}
}

local function build_rows(devices, on_checkbox_click)
    local device_rows = { layout = wibox.layout.fixed.vertical }
    for _, device in pairs(devices) do
        local checkbox = wibox.widget {
            checked = device.is_default,
            color = beautiful.bg_normal,
            paddings = 2,
            shape = gears.shape.circle,
            forced_width = 20,
            forced_height = 20,
            check_color = beautiful.fg_urgent,
            widget = wibox.widget.checkbox
        }

        checkbox:connect_signal('button::press', function()
            wpctl.set_default(device.id)
            on_checkbox_click()
        end)

        local row = wibox.widget {
            {
                {
                    {
                        checkbox,
                        valign = 'center',
                        layout = wibox.container.place,
                    },
                    {
                        {
                            text = device.description,
                            align = 'left',
                            widget = wibox.widget.textbox
                        },
                        left = 10,
                        layout = wibox.container.margin
                    },
                    spacing = 8,
                    layout = wibox.layout.align.horizontal
                },
                margins = 4,
                layout = wibox.container.margin
            },
            bg = beautiful.bg_normal,
            widget = wibox.container.background
        }

        row:connect_signal('mouse::enter', function(c) c:set_bg(beautiful.bg_focus) end)
        row:connect_signal('mouse::leave', function(c) c:set_bg(beautiful.bg_normal) end)

        local old_cursor, old_wibox
        row:connect_signal('mouse::enter', function()
            local wb = mouse.current_wibox
            old_cursor, old_wibox = wb.cursor, wb
            wb.cursor = 'hand1'
        end)
        row:connect_signal('mouse::leave', function()
            if old_wibox then
                old_wibox.cursor = old_cursor
                old_wibox = nil
            end
        end)

        row:connect_signal('button::press', function()
            wpctl.set_default(device.id)
            on_checkbox_click()
        end)

        table.insert(device_rows, row)
    end

    return device_rows
end

local function build_header_row(text)
    return wibox.widget {
        {
            markup = '<b>' .. text .. '</b>',
            align = 'center',
            widget = wibox.widget.textbox
        },
        bg = beautiful.bg_normal,
        widget = wibox.container.background
    }
end

local function rebuild_popup()
    for i = 0, #rows do
        rows[i] = nil
    end

    local sinks, sources = wpctl.get_sinks_and_sources()
    table.insert(rows, build_header_row('SINKS'))
    table.insert(rows, build_rows(sinks, function() rebuild_popup() end))
    table.insert(rows, build_header_row('SOURCES'))
    table.insert(rows, build_rows(sources, function() rebuild_popup() end))

    popup:setup(rows)
end

local function worker(user_args)
    local args = user_args or {}

    local mixer_cmd = args.mixer_cmd
    local widget_type = args.widget_type
    local refresh_rate = args.refresh_rate or 1
    local step = args.step or 5
    local device = args.device or '@DEFAULT_SINK@'
    local tooltip = args.tooltip or false
    local min_volume = math.floor(args.min_volume or 0)
    local max_volume = args.max_volume
    if max_volume then max_volume = math.floor(max_volume) end


    if widget_types[widget_type] == nil then
        volume.widget = widget_types['icon_and_text'].get_widget(args.icon_and_text_args)
    else
        volume.widget = widget_types[widget_type].get_widget(args)
    end

    -- there is a delay between wpctl exiting and the volume/mute being changed,
    -- which can cause a delay of up to the widget's refresh_rate (1s by default)
    -- between the update function executing and the widget visibly updating
    -- keeping track of the volume and mute status locally avoids this
    local status = {
        volume = wpctl.get_volume(device),
        is_muted = wpctl.get_mute(device)
    }

    local function update_status()
        local vol = wpctl.get_volume(device)
        if vol ~= nil then
            status.volume = vol
        end

        status.is_muted = wpctl.get_mute(device)
    end

    local function update_graphic(widget)
        widget:set_volume_level(status.volume)

        if status.is_muted then
            widget:mute()
        else
            widget:unmute()
        end
    end

    function volume:inc(s)
        if not s then s = step end

        if max_volume == nil or status.volume + s <= max_volume then
            status.volume = status.volume + s
            wpctl.volume_increase(device, s or step)
        else
            status.volume = max_volume
            wpctl.volume_set(device, max_volume)
        end

        update_graphic(volume.widget)
    end

    function volume:dec(s)
        if not s then s = step end

        -- wpctl allows setting negative values
        if status.volume - s >= min_volume then
            status.volume = status.volume - s
            wpctl.volume_decrease(device, s or step)
        else
            status.volume = min_volume
            wpctl.volume_set(device, min_volume)
        end

        update_graphic(volume.widget)
    end

    function volume:toggle()
        status.is_muted = not status.is_muted

        wpctl.mute_toggle(device)
        update_graphic(volume.widget)
    end

    function volume:popup()
        if popup.visible then
            popup.visible = not popup.visible
        else
            rebuild_popup()
            popup:move_next_to(mouse.current_widget_geometry)
        end
    end

    function volume:mixer()
        if mixer_cmd then
            spawn(mixer_cmd)
        end
    end

    volume.widget:buttons(
        awful.util.table.join(
            awful.button({}, 1, function() volume:toggle() end),
            awful.button({}, 2, function() volume:mixer() end),
            awful.button({}, 3, function() volume:popup() end),
            awful.button({}, 4, function() volume:inc() end),
            awful.button({}, 5, function() volume:dec() end)
        )
    )

    gears.timer {
        timeout = refresh_rate,
        call_now = true,
        autostart = true,
        callback = function()
            update_status()
            update_graphic(volume.widget)
        end
    }

    if tooltip then
        awful.tooltip {
            objects = { volume.widget },
            timer_function = function()
                return wpctl.get_volume(device) .. ' %'
            end,
        }
    end

    return volume.widget
end


return setmetatable(volume, { __call = function(_, ...) return worker(...) end })
