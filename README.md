# Bazooka

[![CI](https://github.com/to-bak/bazooka.el/actions/workflows/ci.yml/badge.svg)](https://github.com/to-bak/bazooka.el/actions/workflows/ci.yml)

## Wip
> [!NOTE]
> Bazooka is suuuuper vibe-coded and currently validated through automated
> tests and daily personal use. If the package gains wider adoption,
> I'll code it properly xoxo

Bazooka is a tiny package to quickly anchor and switch between window layouts.

## The problems
- Quickly switching between two window layouts can be a hassle.
- Some emacs frameworks like org-agenda might obliterate your window layout;

## The solution
- A buffer of window layouts manually or progamatically managed by the user through `bazooka-remember` and `bazooka-toggle`.

## How it behaves

- Nothing is recorded implicitly. Run `bazooka-remember` or `bazooka-toggle` are
  to save your precious window layout!
- The package maintains a configurable amount of window layouts (default 4).
- The window layouts are sorted and managed internally as MRU. If the capacity of layouts is exceeded, we evict the LRU.
- Some `consult` nicities to preview layouts

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

## Commands

| Command            | Effect                                                         |
|--------------------|----------------------------------------------------------------|
| `bazooka-remember` | Explicitly save or refresh the current layout                  |
| `bazooka-toggle`   | Save the departure layout and restore the newest different one |
| `bazooka-select`   | Pick a layout, using Consult preview when available            |
| `bazooka-consult`  | Require Consult and open the preview picker                    |
| `bazooka-restore`  | Pick and restore an entry, promoting interactive selections    |
| `bazooka-clear`    | Clear the selected frame's saved layouts                       |

Set `bazooka-capacity` to control how many layouts each frame keeps.

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
