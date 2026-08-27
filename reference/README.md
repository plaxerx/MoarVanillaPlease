# Reference art

Source material for the sprites in `assets/`. Work from these rather than redrawing.

| File | What it is |
|---|---|
| `cake_unframed_1x.png` / `_2x.png` | The mod icon before the mod-list frame was added |

The SMODS mod list draws each mod's tag from an atlas SMODS builds itself out of
`assets/1x/<icon_path>` (preflight/loader.lua:749), so the frame has to be part of the icon
image. Its window is x5-28 y5-28 at 1x and x10-57 y10-57 at 2x; the frame itself is the
pixels shared by Erratic Mode's and Endless Engines' icons.
