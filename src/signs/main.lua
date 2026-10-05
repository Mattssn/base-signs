-- Base Signs
-- CC:Tweaked, Minecraft 1.21.1 (ATM10 To the Sky)
--
-- Every monitor (or monitor array) connected to this computer is a sign. Set the text and
-- colors here on the computer; each sign is drawn as big as it fits.

local root = fs.getDir(shell.getRunningProgram())
package.path = "/" .. fs.combine(root, "?.lua") .. ";" .. package.path

local render = require("render")

local CONFIG = "/signs.cfg" -- outside /signs so updates don't wipe it

--------------------------------------------------
-- CONFIG
--------------------------------------------------

-- { [monitor name] = { text, fg, bg, border, style, ignore } }
local signs = {}

local function load()
    if not fs.exists(CONFIG) then
        return
    end

    local file = fs.open(CONFIG, "r")
    local data = textutils.unserialize(file.readAll())
    file.close()

    if type(data) == "table" then
        signs = data
    end
end

local function save()
    local file = fs.open(CONFIG, "w")
    file.write(textutils.serialize(signs))
    file.close()
end

load()

local function monitors()
    local names = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "monitor") then
            table.insert(names, name)
        end
    end

    table.sort(names)

    return names
end

--------------------------------------------------
-- RENDERER
--------------------------------------------------

local drawn = {} -- monitor name -> { w, h } it was last drawn at

local function placeholder(name)
    return { text = "Sign not set up|" .. name, fg = "gray", bg = "black", style = "plain" }
end

local function redraw(name)
    local sign = signs[name]

    if sign and sign.ignore then
        drawn[name] = nil
        return
    end

    local ok, w, h = pcall(render.draw, peripheral.wrap(name), sign or placeholder(name))

    drawn[name] = ok and { w = w, h = h } or nil
end

local function redrawAll()
    for _, name in ipairs(monitors()) do
        redraw(name)
    end
end

-- Big number on every monitor so you can tell them apart
local function identify()
    for i, name in ipairs(monitors()) do
        if not (signs[name] and signs[name].ignore) then
            pcall(render.draw, peripheral.wrap(name), { text = tostring(i), fg = "white", bg = "blue", border = "lightBlue", style = "big" })
        end
    end
end

local function renderer()
    redrawAll()

    while true do
        local event, name = os.pullEvent()

        if event == "peripheral" and peripheral.hasType(name, "monitor") then
            redraw(name)
        elseif event == "peripheral_detach" then
            drawn[name] = nil
        elseif event == "monitor_resize" and drawn[name] then
            -- Changing the text scale while fitting also fires this, so only redraw
            -- if the monitor really changed size (blocks added or removed)
            local w, h = peripheral.call(name, "getSize")

            if w ~= drawn[name].w or h ~= drawn[name].h then
                redraw(name)
            end
        elseif event == "signs_changed" then
            if name then
                redraw(name)
            else
                redrawAll()
            end
        elseif event == "signs_identify" then
            identify()
        end
    end
end

--------------------------------------------------
-- EDITOR (the computer's own screen)
--------------------------------------------------

local COLOR_NAMES = {
    "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray",
    "lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black"
}

-- name, text, background, border
local THEMES = {
    { "Energy", "yellow", "black", "orange" },
    { "Danger", "white", "red", "orange" },
    { "Farms", "lime", "black", "green" },
    { "Storage", "white", "blue", "lightBlue" },
    { "Mobs", "red", "black", "gray" },
    { "Magic", "magenta", "black", "purple" },
    { "Tech", "cyan", "gray", "lightBlue" },
    { "Clean", "black", "white" }
}

local function color(fg, bg)
    term.setTextColor(colors[fg] or colors.white)
    term.setBackgroundColor(colors[bg] or colors.black)
end

local function reset()
    color("white", "black")
end

local function heading(text)
    reset()
    term.clear()
    term.setCursorPos(1, 1)
    color("black", "yellow")
    term.clearLine()
    write(" " .. text)
    reset()
    print()
    print()
end

local function prompt(text, default)
    color("yellow", "black")
    write(text)
    reset()

    local answer = read(nil, nil, nil, default)

    return answer
end

-- First line of a sign for the list
local function summary(sign)
    if not sign then
        return "(not set)"
    elseif sign.ignore then
        return "(ignored)"
    end

    return (sign.text or ""):match("^[^|]*")
end

local function showList()
    heading("Base Signs")

    local names = monitors()

    if #names == 0 then
        print("No monitors connected.")
        print("Connect monitors with wired modems (right-click")
        print("each modem to turn it on) or place one next to")
        print("this computer.")
    end

    for i, name in ipairs(names) do
        local sign = signs[name]

        write(("%2d "):format(i))

        if sign and not sign.ignore then
            color(sign.fg, sign.bg)
            write(" " .. summary(sign) .. " ")
            reset()
        else
            color("gray", "black")
            write(" " .. summary(sign) .. " ")
            reset()
        end

        color("gray", "black")
        print("  " .. name)
        reset()
    end

    print()
    color("lightGray", "black")
    print("<number>  edit that sign")
    print("id        show numbers on the monitors")
    print("off <n>   ignore a monitor (on <n> to undo)")
    print("clear <n> remove a sign's text")
    print("quit")
    reset()

    return names
end

local function pickColor(label, current)
    print()
    print(label .. ":")

    for i, name in ipairs(COLOR_NAMES) do
        write(("%2d "):format(i))
        color(name == "black" and "white" or "black", name)
        write(" " .. name .. string.rep(" ", 10 - #name))
        reset()
        write(i % 3 == 0 and "\n" or "  ")
    end

    print()

    local answer = prompt("Number (Enter keeps " .. tostring(current) .. "): ")
    local n = tonumber(answer)

    return COLOR_NAMES[n] or current
end

local function edit(name)
    local sign = {}

    for k, v in pairs(signs[name] or { fg = "white", bg = "black", style = "auto" }) do
        sign[k] = v
    end

    sign.ignore = nil

    heading("Edit sign: " .. name)
    print("Use | for a new line, e.g. ENERGY|Reactors")
    print()

    local text = prompt("Text: ", sign.text)

    if text == "" and not sign.text then
        return
    end

    sign.text = text ~= "" and text or sign.text

    -- Colors
    print()
    print("Colors:")

    for i, theme in ipairs(THEMES) do
        write(("%2d "):format(i))

        if theme[4] then
            color(theme[2], theme[4])
            write(" ")
        end

        color(theme[2], theme[3])
        write(" " .. theme[1] .. string.rep(" ", 8 - #theme[1]))

        if theme[4] then
            color(theme[2], theme[4])
            write(" ")
        end

        reset()
        write(i % 2 == 0 and "\n" or "    ")
    end

    print(" 9 custom colors")

    local choice = tonumber(prompt("Number (Enter keeps current): "))

    if THEMES[choice] then
        sign.fg, sign.bg, sign.border = THEMES[choice][2], THEMES[choice][3], THEMES[choice][4]
    elseif choice == 9 then
        sign.fg = pickColor("Text color", sign.fg)
        sign.bg = pickColor("Background", sign.bg)

        local border = prompt("Border? (y/n): ", sign.border and "y" or "n")

        sign.border = border:lower():sub(1, 1) == "y" and pickColor("Border color", sign.border or sign.fg) or nil
    end

    -- Style
    print()
    print("Letters: 1 auto (biggest)   2 block letters   3 normal text")

    local style = ({ "auto", "big", "plain" })[tonumber(prompt("Number (Enter keeps " .. (sign.style or "auto") .. "): "))]

    sign.style = style or sign.style or "auto"

    signs[name] = sign
    save()
    os.queueEvent("signs_changed", name)
end

local function editor()
    while true do
        local names = showList()

        print()

        local line = prompt("> ")
        local cmd, arg = line:match("^%s*(%S*)%s*(.-)%s*$")
        local n = tonumber(arg)
        local target = names[n or tonumber(cmd)]

        cmd = cmd:lower()

        if cmd == "quit" or cmd == "exit" then
            return
        elseif cmd == "id" then
            os.queueEvent("signs_identify")
            prompt("Showing numbers. Press Enter to go back.")
            os.queueEvent("signs_changed")
        elseif tonumber(cmd) and target then
            edit(target)
        elseif (cmd == "off" or cmd == "on" or cmd == "clear") and target then
            if cmd == "off" then
                signs[target] = signs[target] or {}
                signs[target].ignore = true
                pcall(peripheral.call, target, "clear")
            elseif cmd == "on" and signs[target] then
                signs[target].ignore = nil

                if not signs[target].text then
                    signs[target] = nil
                end
            elseif cmd == "clear" then
                signs[target] = nil
            end

            save()
            os.queueEvent("signs_changed", target)
        end
    end
end

-- Ctrl+T counts as a clean stop, so startup.lua doesn't restart us
local ok, err = pcall(parallel.waitForAny, renderer, editor)

if not ok and err ~= "Terminated" then
    error(err, 0)
end

reset()
term.clear()
term.setCursorPos(1, 1)
print("Base Signs stopped. The signs stay on the monitors.")
