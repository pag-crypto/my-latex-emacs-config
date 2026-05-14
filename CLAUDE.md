# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A LaTeX-focused Emacs configuration, with a small EasyCrypt path bolted on via Proof General for cryptographic proof work. The "code" here is Emacs Lisp config (`init.el` + `custom.el`); there is no build/test system. Changes are validated by reloading the config in Emacs (`M-x eval-buffer` in `init.el`, or restart).

## Architecture

`init.el` is the single source of truth and is organized as a linear stack of `use-package` blocks. The pieces interact in non-obvious ways — touching one often requires understanding the others:

- **AUCTeX (`tex` / `auctex`)** is the LaTeX major mode. Its `LaTeX-mode` hook is the central wiring point: it turns on **RefTeX** (labels/refs/cites), **cdlatex** (math input), **eglot** (LSP via `texlab`), `TeX-source-correlate-mode` (SyncTeX), and `TeX-PDF-mode`. Anything that should activate per-LaTeX-buffer hooks off `LaTeX-mode`.
- **`auctex-latexmk`** sets `TeX-command-default` to `LatexMk`, so `C-c C-c` runs latexmk. It must load *after* `tex` (hence `:after tex`).
- **eglot LSP server pinning**: eglot's default `eglot-server-programs` table ships entries for *both* `texlab` and `digestif`, so if both are on `PATH` it prompts at every startup. `init.el` prepends `((latex-mode LaTeX-mode plain-tex-mode) . ("texlab"))` via `with-eval-after-load 'eglot` to make texlab the silent winner. If a user reports being prompted again, this is the line to check.
- **In-buffer completion (corfu + cape)**: `corfu` provides the popup; `cape` merges multiple capf sources via `cape-capf-super`. Necessary because eglot's capf is *exclusive* by default and would shadow AUCTeX's own `TeX--completion-at-point` (which is the only source for project-local `\newcommand` macros that texlab doesn't see). The merged capf is set buffer-locally via `my/latex-capf` on `LaTeX-mode-hook`. Order matters: eglot first, then AUCTeX, then citar; `cape-file` and `cape-dabbrev` are appended as fallbacks.
- **PDF viewing** is wired in a `with-eval-after-load 'tex` block that sets `TeX-view-program-selection`/`-list` to PDF Tools and adds `TeX-revert-document-buffer` to `TeX-after-compilation-finished-functions`. This is intentionally lazy: `pdf-tools` is loaded on demand via the `:magic ("%PDF" . pdf-view-mode)` trigger when AUCTeX opens the output PDF. Don't move these settings into `pdf-tools`'s `:config` — they belong to AUCTeX.
- **PDF auto-revert race**: `global-auto-revert-mode` is on with a 1-second poll for source files. PDFs **must not** poll-revert — pdf-tools re-reads the file mid-render and races latexmk's progressive write, producing `"epdfinfo: Error opening …: PDF document is damaged"`. `init.el` disables auto-revert in `pdf-view-mode-hook` (with explicit `-1`, *not* a bare `auto-revert-mode` symbol — that toggles); the PDF buffer is instead reverted cleanly by `TeX-after-compilation-finished-functions` after latexmk exits. `revert-without-query` includes `\\.pdf\\'` to silence prompts on the rare path where revert does fire.
- **No continuous scroll for PDFs**: `pdf-tools` runs page-by-page (`n`/`p` to advance). A previous setup used `image-roll` (`:vc` from `dalanicolai/image-roll.el`) to add smooth scrolling but it produced spurious `(wrong-type-argument overlayp nil)` errors from its `pre-redisplay` hook and was removed. `custom.el` still lists `image-roll` and `pdf-continuous-scroll-mode` under `package-vc-selected-packages` — leftover entries; harmless, but they'll re-fetch on a fresh install. Don't re-enable image-roll without first checking whether upstream has been actively maintained.
- **PDF window placement** is dynamic. A small system around `paul/pdf-display-mode` (a defvar holding `'side` or `'frame`) installs a `display-buffer-alist` entry matching `\\.pdf\\'`. Mode `'side` puts PDFs in a 50%-width right side window; mode `'frame` pops them into their own OS-level Emacs frame. `paul/toggle-pdf-display` (bound to `C-c P`) swaps modes and re-displays any visible PDFs under the new rule. `paul/jump-pdf` (bound to `C-c p`) toggles input focus between the current source buffer and a PDF buffer, including across frames via `select-frame-set-input-focus`. Editing the rules: `paul/--pdf-display-rule`. Editing the bindings: the two `global-set-key` calls at the end of the block.
- **Citations** have two paths: RefTeX's `C-c [` and **citar** (`citar-capf-setup` is on both `LaTeX-mode` and `org-mode` hooks for completion-at-point, and the merged capf above also calls `citar-capf` directly). `citar-bibliography` points at `~/bibliography.bib` — change this when the user's bib path differs.
- **Minibuffer stack**: vertico + marginalia + orderless + savehist + `consult` (search/jump) + `embark` (act-on-thing) + `embark-consult` glue. `orderless` is the primary `completion-styles` with a `file` override that falls back to basic + partial-completion (so file-path completion still feels right). consult bindings replace `C-x b`, `M-y`, `M-g g`, `M-g i`, and add `M-s l` / `M-s r`; embark-act is on `C-.`. `consult-ripgrep` needs `rg` on `PATH`.
- **`which-key`** is on globally — passive UX, just shows continuations after a prefix delay. No interactions with anything else.
- **`yasnippet`** runs as `yas-global-mode`, with `yasnippet-snippets` providing the bundled snippet pack (incl. LaTeX). User snippets live under `~/.emacs.d.latex/snippets/<mode>/`. `TAB` is the expansion key, which can collide with corfu's `TAB`; in practice yasnippet wins when at a snippet trigger and corfu wins otherwise.
- **`preview-latex`** ships with AUCTeX. `preview-scale-function` is set to `0.85` via `with-eval-after-load 'preview` to keep wide equations from overflowing the narrow source window (the side-window PDF would otherwise occlude them). Tune this number if equations are clipped (smaller) or hard to read (larger).
- **`gptel`** is configured with the Anthropic backend; `gptel-model` is currently `claude-sonnet-4-20250514`. Auth is via `auth-source` (`gptel-api-key-from-auth-source`), not a hardcoded key.
- **`claude-code-ide`** runs the Claude Code CLI in an in-Emacs terminal and speaks MCP back to Emacs (xref/imenu/project tools via `claude-code-ide-emacs-tools-setup`). Not on MELPA — installed via `:vc` from `manzaltu/claude-code-ide.el`. Terminal backend is pinned to `eat` (pure elisp) rather than `vterm` to avoid the cmake + libvterm-dev build dep; flip `claude-code-ide-terminal-backend` to `'vterm` if vterm is already available. The CLI itself (`claude`) is an external dependency — `claude-code-ide-cli-path` overrides the lookup. Global keybinding `C-c C-'` opens the menu transient. Independent of the LaTeX stack; the buffer-name-based `display-buffer-alist` PDF rule does not match its terminal buffer names.
- **`proof-general`** is installed via plain `(use-package proof-general)` — no LaTeX-side wiring. Opening a `.ec` file autoloads `easycrypt-mode` and starts PG's proof-script / `*goals*` / `*response*` window layout. PG is mode-scoped and does not register a global capf, so corfu/cape work in proof buffers without explicit setup. Requires the `easycrypt` binary on `PATH`; pin per-project via `.dir-locals.el` setting `easycrypt-prog-name` if a wrapper is needed. The `\\.pdf\\'` `display-buffer-alist` rule does not match PG buffer names, so the PDF window system does not interfere.

## External dependencies (not installed by Emacs)

- **`texlab`** — required for `eglot` to do anything useful in LaTeX. Install via distro package manager or `cargo install --locked texlab`. eglot will silently no-op if absent.
- **`epdfinfo`** — pdf-tools' helper, built on first launch via `M-x pdf-tools-install`. Needs libpng, poppler-glib, and a C toolchain on the system.
- **`latexmk`** — invoked by `auctex-latexmk` for the default build command.
- **`rg`** (ripgrep) — needed by `consult-ripgrep` (`M-s r`). Soft dep: that one command no-ops without it; everything else still works.
- **`easycrypt`** — required for Proof General to actually drive an EasyCrypt session. Install per the upstream instructions at https://www.easycrypt.info/. Without it, opening `.ec` files still enters `easycrypt-mode` (font-lock works) but `proof-assert-next-command` etc. will fail when PG tries to spawn the prover.
- **`claude`** (Claude Code CLI) — required for `claude-code-ide` to spawn a session. Install per https://claude.com/claude-code. Without it, `M-x claude-code-ide` errors out when it tries to launch the subprocess; everything else still works.

## Conventions

- `custom.el` is the user's Customize-managed file (themes, package-vc selections). Don't move settings from `init.el` into it or vice versa unless asked — the split is intentional.
- `use-package-always-ensure` is `t`, so any new `use-package` block will auto-install from MELPA. Use `:ensure nil` for built-ins (see `savehist`).
- The `LaTeX-mode` hook list in the AUCTeX block is the canonical place to add new per-LaTeX-buffer behavior.
- `CHEATSHEET.md` is user-facing key reference. Keep it in sync if a new keybinding/workflow is added to `init.el`.

## Validating changes

There is no CI or test runner. After editing `init.el`:
1. `emacs --debug-init` from a shell to surface load errors, or
2. Inside Emacs: `M-x eval-buffer` on `init.el` (won't catch `:hook`/`:custom` ordering issues that only manifest on fresh start).

For package issues: `M-x package-refresh-contents`, then `M-x package-upgrade-all` (Emacs 29+).
