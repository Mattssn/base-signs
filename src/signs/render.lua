-- Base Signs: draws one sign on one monitor, as big as it fits
--
-- Every text scale (5 down to 0.5) is tried in two styles:
--   big:   block letters made of colored cells (font.lua), 5 rows tall
--   plain: normal monitor text
-- and the one with the tallest letters that still fits wins.

local font = require("font")

local render = {}

local SCALES = { 5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 0.5 }

-- Borders are a fixed physical width (3/16 of a block) so every sign gets the same frame.
-- A text cell is 6/64 x 9/64 of a block times the scale, which makes the border 2/scale
-- cells on both axes: only a whole number at scales 2, 1 and 0.5.
local BORDER_SCALES = { 2, 1, 0.5 }

-- How tall letters look, in "scale units": block letters fill 5 whole cells; normal
-- capitals only fill about 7 of a cell's 9 pixel rows.
local PLAIN_HEIGHT = 7 / 9
-- A font pixel is 2 cells wide by 1 tall (cells are about 1.5x taller than wide), times a
-- zoom of 1, 2, 3... so block letters can grow in steps between text scales.
local PIXEL_W = 2
local LETTER_GAP = 2 -- cells between block letters (times zoom)
local LINE_GAP = 1   -- rows between lines of block letters (times zoom)
local MAX_ZOOM = 8

--------------------------------------------------
-- LAYOUT
--------------------------------------------------

local function plainWidth(text)
    return #text
end

local function bigWidth(text, zoom)
    local width = 0

    for i = 1, #text do
        width = width + #font.glyph(text:sub(i, i))[1] * PIXEL_W
    end

    return (width + math.max(0, #text - 1) * LETTER_GAP) * zoom
end

local function bigHeight(lines, zoom)
    return (#lines * (font.HEIGHT + LINE_GAP) - LINE_GAP) * zoom
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

-- Border and margin thickness in cells at this scale
local function borderCells(scale)
    return math.floor(2 / scale + 0.5)
end

local function padding(sign, scale)
    if sign.border then
        -- Border plus a gap of half its width (none at scale 2, where half a cell isn't
        -- possible; the font's own spacing keeps text off the border there)
        return borderCells(scale) + math.floor(1 / scale)
    end

    return math.max(1, math.floor(1 / scale + 0.5))
end

local function layout(sign, style, scale, w, h, zoom)
    local pad = padding(sign, scale)
    local width, height = w - pad * 2, h - pad * 2
    local text = sign.text or ""

    if style == "big" then
        local lines = wrap(text:upper(), width, function(line)
            return bigWidth(line, zoom)
        end)

        if lines and bigHeight(lines, zoom) <= height then
            return lines
        end
    else
        local lines = wrap(text, width, plainWidth)

        if lines and #lines <= height then
            return lines
        end
    end
end

-- Pick the style, text scale and zoom with the tallest letters.
-- Returns style, scale, lines, zoom (or nil if nothing fits).
local function choose(mon, sign)
    local styles = sign.style == "big" and { "big" } or sign.style == "plain" and { "plain" } or { "big", "plain" }
    local best

    for _, scale in ipairs(sign.border and BORDER_SCALES or SCALES) do
        mon.setTextScale(scale)

        local w, h = mon.getSize()

        for _, style in ipairs(styles) do
            for zoom = 1, style == "big" and MAX_ZOOM or 1 do
                local lines = layout(sign, style, scale, w, h, zoom)

                if not lines then
                    break -- a bigger zoom won't fit either
                end

                local height = style == "big" and scale * font.HEIGHT * zoom or scale * PLAIN_HEIGHT

                -- On a tie, prefer plain text (crisper), then the larger text scale (fewer cells)
                if not best or height > best.height
                    or (height == best.height and (style == "plain" or scale > best.scale)) then
                    best = { style = style, scale = scale, lines = lines, height = height, zoom = zoom }
                end
            end
        end
    end

    if best then
        return best.style, best.scale, best.lines, best.zoom
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

local function drawBorder(mon, w, h, size, color)
    for i = 0, size - 1 do
        fill(mon, 1, 1 + i, w, color)
        fill(mon, 1, h - i, w, color)
    end

    for y = 1 + size, h - size do
        fill(mon, 1, y, size, color)
        fill(mon, w - size + 1, y, size, color)
    end
end

local function drawBig(mon, lines, top, w, fg, zoom)
    local pixelW = PIXEL_W * zoom

    for i, line in ipairs(lines) do
        local y = top + (i - 1) * (font.HEIGHT + LINE_GAP) * zoom
        local x = math.floor((w - bigWidth(line, zoom)) / 2) + 1

        for c = 1, #line do
            local glyph = font.glyph(line:sub(c, c))

            for row = 1, font.HEIGHT do
                local pixels = glyph[row]

                for col = 1, #pixels do
                    if pixels:sub(col, col) == "#" then
                        for dy = 0, zoom - 1 do
                            fill(mon, x + (col - 1) * pixelW, y + (row - 1) * zoom + dy, pixelW, fg)
                        end
                    end
                end
            end

            x = x + #glyph[1] * pixelW + LETTER_GAP * zoom
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
    local style, scale, lines, zoom = choose(mon, sign)

    scale = scale or 0.5
    mon.setTextScale(scale)

    local w, h = mon.getSize()

    mon.setBackgroundColor(bg)
    mon.clear()

    if sign.border and colors[sign.border] then
        drawBorder(mon, w, h, borderCells(scale), colors[sign.border])
    end

    if not lines then
        -- Too long for this monitor even at the smallest size
        lines = { "Text too long" }
        style = "plain"
    end

    local contentHeight = style == "big" and bigHeight(lines, zoom) or #lines
    local top = math.floor((h - contentHeight) / 2) + 1

    if style == "big" then
        drawBig(mon, lines, top, w, fg, zoom)
    else
        drawPlain(mon, lines, top, w, fg, bg)
    end

    mon.setBackgroundColor(colors.black)

    return w, h
end

return render
