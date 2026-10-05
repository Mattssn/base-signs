-- Base Signs boot: runs the sign editor and restarts it if it crashes.
-- Typing `quit` (or Ctrl+T) exits cleanly to the shell. Hold Ctrl+T to break out of a crash loop.

while true do
    if shell.run("/signs/main.lua") then
        break
    end

    print("Base Signs crashed. Restarting in 5s...")
    sleep(5)
end
