# README screenshots

Maintainer tooling for the images linked from the root [README](../../README.md). Not used by the plugin at runtime.

| File | Description |
|------|-------------|
| `picker-with-preview.png` | History list + syntax-highlighted preview |
| `picker-empty.png` | Empty ring (list only) |

## Regenerate (macOS)

Requires [WezTerm](https://wezfurlong.org/wezterm/) and Screen Recording permission for your terminal.

```bash
./doc/screenshots/capture.sh        # both images
./doc/screenshots/capture.sh full   # preview shot only
./doc/screenshots/capture.sh empty  # empty ring only
```

Preview a demo without capturing:

```bash
./doc/screenshots/open_demo.sh full
```

Demos use `nvim --clean` so your personal config does not override the sample yanks.

On other platforms, open a demo and use your OS screenshot tool:

```bash
nvim --clean --cmd "cd $(pwd)" --cmd "luafile doc/screenshots/demo.lua"
```
