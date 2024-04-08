local spawn = require("awful.spawn")

local wpctl = {}

local function popen_and_return(cmd)
    local handle = io.popen(cmd)
    local result = handle:read('*a')
    handle:close()

    if result == nil then
        return ''
    end

    return result
end

function wpctl.volume_increase(device, step)
    spawn('wpctl set-volume ' .. device .. ' ' .. step .. '%+', false)
end

function wpctl.volume_decrease(device, step)
    spawn('wpctl set-volume ' .. device .. ' ' .. step .. '%-', false)
end

function wpctl.volume_set(device, volume)
    spawn('wpctl set-volume ' .. device .. ' ' .. volume .. '%', false)
end

function wpctl.mute_toggle(device)
    spawn('wpctl set-mute ' .. device .. ' toggle', false)
end

function wpctl.get_volume(device)
    local stdout = popen_and_return('LC_ALL=C wpctl get-volume ' .. device)

    return math.floor(tonumber(string.match(stdout, '%d*%.%d*')) * 100)
end

function wpctl.get_mute(device)
    local stdout = popen_and_return('LC_ALL=C wpctl get-volume ' .. device)
    if string.find(stdout, 'MUTED') then
        return true
    else
        return false
    end
end

local function parse_sink_or_source_line(line)
    local default, id, description = string.match(line, '^ │[ ]*(%*?)[ ]*(%d+)%. (.*)[ ]*%[.*%]$')

    -- default device is indicated by a * near the beginning of the line
    local is_default = default == '*'

    return {
        id = id,
        description = description,
        is_default = is_default,
    }
end

function wpctl.get_sinks_and_sources()
    local sinks = {}
    local sources = {}

    local in_audio_section = false
    local in_sinks_section = false
    local in_sources_section = false

    for line in popen_and_return('LC_ALL=C wpctl status'):gmatch('[^\r\n]*') do
        if line == 'Audio' then
            in_audio_section = true
        elseif line == ' ├─ Sinks:' then
            in_sinks_section = true
        elseif line == ' ├─ Sources:' then
            in_sources_section = true
        elseif line == ' │  ' then
            in_sinks_section = false
            in_sources_section = false
        elseif line == '' and in_audio_section then
            break
        elseif in_sinks_section then
            table.insert(sinks, parse_sink_or_source_line(line))
        elseif in_sources_section then
            table.insert(sources, parse_sink_or_source_line(line))
        end
    end

    return sinks, sources
end

function wpctl.set_default(device)
    spawn('wpctl set-default ' .. device, false)
end

return wpctl
