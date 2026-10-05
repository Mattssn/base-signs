# Base Signs

Big, colorful signs for your base on CC: Tweaked monitors, e.g. **ENERGY**, **MOBS** or **STORAGE**.
It's made for **All the Mods 10: To the Sky** (Minecraft 1.21.1). It's a companion to [Base OS](https://github.com/Mattssn/base-os).

Every monitor (or monitor array) connected to the computer is a sign. You set the text and colors on the
computer, and each sign is drawn **as big as it fits**. Base Signs tries every text scale with chunky
block letters and with normal text, then picks whichever gives the tallest letters.

## Install
Use a **separate computer** from Base OS. Both use `startup.lua`.
```
wget run https://raw.githubusercontent.com/Mattssn/base-signs/main/install.lua
```
Run the same command again to update. Your signs are saved in `/signs.cfg` and are kept.

## Hooking up monitors
- Use **advanced monitors** for color. Place them side by side to make one bigger sign.
- Connect each sign with a **wired modem** and networking cable. Right-click each modem to turn it on.
  You can also put one monitor right next to the computer.
- Wireless modems can't connect monitors.

**Sharing cable with Base OS?** Base OS would take over the sign monitors too. On the Base OS computer, run
`set baseos.pin.monitor_7 off` for each sign monitor, then reboot.

## Using it
The computer lists every monitor:

| Command | |
|---|---|
| `<number>` | edit that sign: text, colors, letter style |
| `id` | show a big number on each monitor so you can tell which is which |
| `off <n>` / `on <n>` | ignore a monitor (Base Signs leaves it alone) |
| `clear <n>` | remove a sign |
| `quit` | stop (signs stay on screen) |

- **Text:** use `|` for a new line, e.g. `MOB FARM|Spawners`. Long text wraps automatically.
- **Colors:** pick a theme (Energy, Danger, Farms, Storage, Mobs, Magic, Tech, Clean), or choose the text, background and border colors yourself.
- **Letters:** *auto* picks the biggest. *Block letters* always uses chunky letters (A-Z, 0-9 and common symbols). *Normal text* always uses the monitor font.

Signs redraw by themselves when you add or remove monitor blocks.

## Files
```
install.lua        one-command installer/updater
src/startup.lua    runs Base Signs on boot, restarts it if it crashes
src/signs/main.lua editor + renderer
src/signs/render.lua  picks the text scale and style, draws the sign
src/signs/font.lua    block letter font
```
