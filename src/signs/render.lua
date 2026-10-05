-- Base Signs: draws one sign on one monitor, as big as it fits
--
-- Every text scale (5 down to 0.5) is tried in two styles:
--   big:   block letters made of colored cells (font.lua), 5 rows tall
--   plain: normal monitor text
-- and the one with the tallest letters that still fits wins.

local font = require("font")

local render = {}

local SCALES = { 5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 0.5 }
local PIXEL_W = 2    -- a font pixel is 2 cells wide (cells are about 1.5x taller than wide)
local LETTER_GAP = 2 -- cells between block letters
local LINE_GAP = 1   -- rows between lines of block letters

--------------------------------------------------
-- LAYOUT
--------------------------------------------------

local function plainWidth(text)
    return #text
end

local function bigWidth(text)
    local width = 0

    for i = 1, #text do
        width = width + #font.glyph(text:sub(i, i))[1] * PIXEL_W
    end

    return width + math.max(0, #text - 1) * LETTER_GAP
end

-- Split on "|" and word-wrap each part to `width`. Returns nil if a word can't fit.
local function wrap(text, width, measure)
    local lines = {}

    for part in (text .. "|"):gmatch("(.-)|") do
        local line = ""

        for word in part:gmatch("%S+") do
            local candidate = line == "" and word or line .. " " .. word

            if measure(candidate) <= width then
                line = candidate
            elseif measure(word) <= width then
                table.insert(lines, line)
                line = word
            else
                return nil
            end
        end

        table.insert(lines, line)
    end

    return lines
end

-- Space inside the border/margin
local function inner(sign, w, h)
    local pad = sign.border and 2 or 1

    return w - pad * 2, h - pad * 2, pad
end

local function layout(sign, style, w, h)
    local width, height = inner(sign, w, h)
    local text = sign.text or ""

    if style == "big" then
        local lines = wrap(text:upper(), width, bigWidth)

        if lines and #lines * (font.HEIGHT + LINE_GAP) - LINE_GAP <= height then
            return lines
        end
    else
        local lines = wrap(text, width, plainWidth)

        if lines and #lines <= height then
            return lines
        end
    end
end

-- Pick the style and text scale with the tallest letters.
-- Returns style, scale, lines (or nil if nothing fits).
local function choose(mon, sign)
    local styles = sign.style == "big" and { "big" } or sign.style == "plain" and { "plain" } or { "big", "plain" }
    local best

    for _, scale in ipairs(SCALES) do
        mon.setTextScale(scale)

        local w, h = mon.getSize()

        for _, style in ipairs(styles) do
            local lines = layout(sign, style, w, h)

            if lines then
                -- Letter height in "scale units": block letters are 5 rows tall
                local height = style == "big" and scale * font.HEIGHT or scale

                -- On a tie, plain text is crisper
                if not best or height > best.height or (height == best.height and style == "plain") then
                    best = { style = style, scale = scale, lines = lines, height = height }
                end
            end
        end
    end

    if best then
        return best.style, best.scale, best.lines
    end
end

--------------------------------------------------
-- DRAWING
--------------------------------------------------

local function fill(mon, x, y, width, color)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(color)
    mon.write(string.rep(" ", width))
end

local function drawBorder(mon, w, h, color)
    fill(mon, 1, 1, w, color)
    fill(mon, 1, h, w, color)

    for y = 2, h - 1 do
        fill(mon, 1, y, 1, color)
        fill(mon, w, y, 1, color)
    end
end

local function drawBig(mon, lines, top, w, fg)
    for i, line in ipairs(lines) do
        local y = top + (i - 1) * (font.HEIGHT + LINE_GAP)
        local x = math.floor((w - bigWidth(line)) / 2) + 1

        for c = 1, #line do
            local glyph = font.glyph(line:sub(c, c))

            for row = 1, font.HEIGHT do
                local pixels = glyph[row]

                for col = 1, #pixels do
                    if pixels:sub(col, col) == "#" then
                        fill(mon, x + (col - 1) * PIXEL_W, y + row - 1, PIXEL_W, fg)
                    end
                end
            end

            x = x + #glyph[1] * PIXEL_W + LETTER_GAP
        end
    end
end

local function drawPlain(mon, lines, top, w, fg, bg)
    mon.setTextColor(fg)
    mon.setBackgroundColor(bg)

    for i, line in ipairs(lines) do
        mon.setCursorPos(math.floor((w - #line) / 2) + 1, top + i - 1)
        mon.write(line)
    end
end

-- sign = { text, fg, bg, border, style } with colors as names ("yellow").
-- Returns the monitor size it was drawn at, so resizes can be detected.
function render.draw(mon, sign)
    local fg = colors[sign.fg] or colors.white
    local bg = colors[sign.bg] or colors.black
    local style, scale, lines = choose(mon, sign)

    mon.setTextScale(scale or 0.5)

    local w, h = mon.getSize()

    mon.setBackgroundColor(bg)
    mon.clear()

    if sign.border and colors[sign.border] then
        drawBorder(mon, w, h, colors[sign.border])
    end

    if not lines then
        -- Too long for this monitor even at the smallest size
        lines = { "Text too long" }
        style = "plain"
    end

    local contentHeight = style == "big" and #lines * (font.HEIGHT + LINE_GAP) - LINE_GAP or #lines
    local top = math.floor((h - contentHeight) / 2) + 1

    if style == "big" then
        drawBig(mon, lines, top, w, fg)
    else
        drawPlain(mon, lines, top, w, fg, bg)
    end

    mon.setBackgroundColor(colors.black)

    return w, h
end

return render
