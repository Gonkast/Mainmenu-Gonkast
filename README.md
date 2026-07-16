# Mainmenu - Gonkast

A cosmetic skin for World of Warcraft's default Game Menu (the Escape / "Game Menu" panel).
Standalone, no dependencies.

Hides Blizzard's default frame art and button textures and replaces them with bundled artwork
(background/border, banner header, wood/red buttons), while leaving the actual buttons/attributes
untouched — only textures and regions are re-skinned, so the protected Logout / Quit buttons keep
working normally (taint-safe).

Optional touches (toggleable in `Core.lua`):
- Decorative header banner with title text.
- Character portrait (3D model or 2D) shown inside the header.

## Installation

1. Click **Code → Download ZIP** above.
2. Extract it. The extracted folder will be named `Mainmenu-Gonkast-main` — **rename it to
   exactly `Mainmenu-Gonkast`** (no `-main` suffix). WoW requires the folder name to match the
   `.toc` file inside it, or the addon won't show up in-game.
3. Move that folder into `World of Warcraft\_retail_\Interface\AddOns\`.
4. Restart WoW (or reload the AddOns list at the character screen).

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
