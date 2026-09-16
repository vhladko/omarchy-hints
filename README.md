# Shortcut hints

Hold Super to peek at the same shortcuts Super + K lists. A full-width bar on the bottom, grouped, filtered by the modifiers you are holding.

Click the keyboard chip on the bar for **Full**, **Beginner**, or **Off**.

<video src="demo.mp4" poster="preview.jpg" controls muted width="100%"></video>

[Watch the demo](demo.mp4)

## Install

```bash
omarchy plugin add https://github.com/vhladko/omarchy-hints.git --enable
```

That turns the overlay on and should put the chip on the right of the bar. If Super works but there is no chip:

```bash
omarchy bar put vhladko.hints --section right
```

Then `omarchy restart shell` if either still does not show.

The plugin writes a marked block into `~/.config/hypr/bindings.lua` so it can see Super without stealing it. Enabling the plugin is what turns that on.

## Use

- Hold Super: show shortcuts for that chord (add Shift / Ctrl / Alt to filter)
- Bar chip: open the mode menu
- Beginner: a short set (menu, terminal, browser, files, close, fullscreen, float, workspaces)
- Super + K: searchable full list (unchanged)

## Remove

```bash
~/.config/omarchy/plugins/vhladko.hints/scripts/off
omarchy plugin remove vhladko.hints
```

Run `scripts/off` **before** remove so the Hyprland hook is deleted. If you already removed the plugin, delete the block between `-- vhladko.hints:begin` and `-- vhladko.hints:end` in `~/.config/hypr/bindings.lua`, then `hyprctl reload`.

## Dependencies

Omarchy 4 (Quattro) with `omarchy-shell` and Hyprland Lua config. Uses `omarchy-menu-keybindings`, `hyprctl`, and (if present) `xkbcli` + `jq` to map Super after layout remaps.

## License

MIT
