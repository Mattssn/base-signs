-- Base Signs installer / updater
-- In game: wget run https://raw.githubusercontent.com/Mattssn/base-signs/main/install.lua
--
-- Downloads everything under src/ in the repo onto this computer, then reboots.
-- Your signs (/signs.cfg) are kept.

local REPO = "Mattssn/base-signs"
local BRANCH = "main"

if not http then
    error("HTTP is disabled on this server (CC:Tweaked config: http.enabled)", 0)
end

local function get(url)
    local response, err = http.get(url)

    if not response then
        error("Download failed: " .. url .. "\n" .. tostring(err), 0)
    end

    local body = response.readAll()
    response.close()

    return body
end

local function getJSON(url)
    return textutils.unserializeJSON(get(url))
end

-- Base Signs replaces startup.lua, so it needs its own computer
if fs.exists("/baseos") then
    printError("This computer runs Base OS.")
    print("Base Signs replaces startup.lua, so Base OS would stop starting.")
    print("Use a separate computer for signs.")
    write("Install anyway? (y/n) ")

    if read():lower():sub(1, 1) ~= "y" then
        return
    end
end

--------------------------------------------------
-- FIND FILES
--------------------------------------------------

print("Base Signs installer")
print("Fetching file list...")

-- Pin to the exact commit so GitHub's raw-file cache can't serve old files
local branch = getJSON("https://api.github.com/repos/" .. REPO .. "/branches/" .. BRANCH)
local commit = branch.commit.sha
local tree = getJSON("https://api.github.com/repos/" .. REPO .. "/git/trees/" .. commit .. "?recursive=1")

local files = {}

for _, entry in ipairs(tree.tree) do
    if entry.type == "blob" and entry.path:sub(1, 4) == "src/" then
        table.insert(files, entry.path)
    end
end

if #files == 0 then
    error("No files found in " .. REPO .. "/src", 0)
end

--------------------------------------------------
-- DOWNLOAD
--------------------------------------------------

-- Remove the old install so deleted files don't linger
if fs.exists("/signs") then
    fs.delete("/signs")
end

local raw = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commit .. "/"

for i, path in ipairs(files) do
    local target = "/" .. path:sub(5)

    print(("[%d/%d] %s"):format(i, #files, target))

    local body = get(raw .. path)
    local dir = fs.getDir(target)

    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(target, "w")
    file.write(body)
    file.close()
end

print("Installed Base Signs (" .. commit:sub(1, 7) .. ")")
print("Rebooting in 3s...")
sleep(3)
os.reboot()
