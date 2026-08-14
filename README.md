# Bazooka

[![CI](https://github.com/to-bak/bazooka.el/actions/workflows/ci.yml/badge.svg)](https://github.com/to-bak/bazooka.el/actions/workflows/ci.yml)

> [!NOTE]
> Bazooka is suuuuper vibe-coded and currently validated through automated
> tests and daily personal use. If the package gains wider adoption,
> I'll code it properly xoxo

Bazooka is a tiny, explicit safety net for Emacs window layouts. Remember a
useful layout, let an agenda, dashboard, or an enthusiastic command take over
the frame, and restore your checkpoint later.

It is deliberately **not** a workspace or buffer-isolation package. Bazooka
does not manage projects, tabs, activities, or which buffers belong together.
It only records window layouts when you ask it to.

## How it behaves

- Saved layouts are local to each frame.
- Nothing is recorded implicitly. `bazooka-remember` and `bazooka-toggle` are
  the only commands that save a layout.
- The default capacity is four layouts. Remembering a fifth evicts the oldest.
- Remembering an equivalent visible layout refreshes it instead of adding a
  duplicate.
- Restoring or previewing a layout does not change the saved list.
- `bazooka-toggle` remembers the layout you are leaving, then jumps to the
  newest different saved layout. Repeating it swaps naturally between layouts.
- Saved layouts live only for the Emacs session. Bazooka intentionally does not
  persist buffers or window state to disk.

## Requirements

- Emacs 29.1 or newer
- [Consult](https://github.com/minad/consult) is optional and enables live
  whole-layout previews in the picker

## Installation

With `package-vc` on Emacs 30:

```elisp
(package-vc-install "https://github.com/to-bak/bazooka.el")
```

With `use-package` and `package-vc`:

```elisp
(use-package bazooka
  :vc (:url "https://github.com/to-bak/bazooka.el"))
```

With straight.el:

```elisp
(use-package bazooka
  :straight (:type git :host github :repo "to-bak/bazooka.el"))
```

For local development, put the checkout on `load-path`:

```elisp
(use-package bazooka
  :load-path "~/git/bazooka.el")
```

Bazooka installs no global keybindings. One possible setup is:

```elisp
(keymap-global-set "C-c f r" #'bazooka-remember)
(keymap-global-set "C-c f f" #'bazooka-toggle)
(keymap-global-set "C-c f b" #'bazooka-select)
(keymap-global-set "C-c f c" #'bazooka-clear)
```

## Commands

| Command | Effect |
| --- | --- |
| `bazooka-remember` | Explicitly save or refresh the current layout |
| `bazooka-toggle` | Save the departure layout and restore the newest different one |
| `bazooka-select` | Pick a layout, using Consult preview when available |
| `bazooka-consult` | Require Consult and open the preview picker |
| `bazooka-restore` | Pick and restore an entry without reordering saved layouts |
| `bazooka-clear` | Clear the selected frame's saved layouts |

Set `bazooka-capacity` to control how many layouts each frame keeps. Set
`bazooka-preview-key` using the same forms accepted by Consult's preview-key
settings; for example, use `nil` to disable previews or `"M-."` for manual
preview.

## Development

Run the byte compiler and ERT suite:

```sh
make check
```

If `package-lint` is installed, validate package metadata and conventions:

```sh
make lint
```

## License

MIT. See [LICENSE](LICENSE).
