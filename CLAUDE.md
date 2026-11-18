# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A LaTeX-focused Emacs configuration, with a small EasyCrypt path bolted on via Proof General for cryptographic proof work. The "code" here is Emacs Lisp config (`init.el` + `custom.el`); there is no build/test system. Changes are validated by reloading the config in Emacs (`M-x eval-buffer` in `init.el`, or restart).

## Architecture

`init.el` is the single source of truth and is organized as a linear stack of `use-package` blocks. The pieces interact in non-obvious ways — touching one often requires understanding the others:

- **AUCTeX (`tex` / `auctex`)** is the LaTeX major mode. Its `LaTeX-mode` hook is the central wiring point: it turns on **RefTeX** (labels/refs/cites), **cdlatex** (math input), **eglot** (LSP via `texlab`), `TeX-source-correlate-mode` (SyncTeX), and `TeX-PDF-mode`. Anything that should activate per-LaTeX-buffer hooks off `LaTeX-mode`.
- **`auctex-latexmk`** sets `TeX-command-default` to `LatexMk`, so `C-c C-c` runs latexmk. It must load *after* `tex` (hence `:after tex`).
- **eglot LSP server pinning**: eglot's default `eglot-server-programs` table ships entries for *both* `texlab` and `digestif`, so if both are on `PATH` it prompts at every startup. `init.el` prepends `((latex-mode LaTeX-mode plain-tex-mode) . ("texlab"))` via `with-eval-after-load 'eglot` to make texlab the silent winner. If a user reports being prompted again, this is the line to check.
- **`M-.` fallback for TeX macros**: an `:around` method on `xref-backend-definitions` for the `eglot` backend (in `with-eval-after-load 'eglot`, right after the texlab pinning) only acts when eglot returns no definitions *and* the buffer derives from `TeX-mode`. texlab misses macros used with a trailing `_`/`:` (it lexes `\pk_i` as the expl3 name `\pk_i`), `\DeclarePairedDelimiter` macros, and package/kernel commands like `\gets`. The fallback (`my/latex-fallback-definitions`) takes the control word at point (stopping at the first non-letter), regex-searches the master's `\input`/`\include`/local-`.sty` tree, then all project `.tex/.sty/.cls`, then runs `texdef -t latex -F` with the master preamble's `\documentclass`/`\usepackage` lines (~1 s) and jumps into the package file (or `fontmath.ltx`/`latex.ltx` for kernel commands). References (`M-?`), apropos, and non-TeX eglot buffers are untouched.
- **In-buffer completion (corfu + cape)**: `corfu` provides the popup; `cape` merges multiple capf sources via `cape-capf-super`. Necessary because eglot's capf is *exclusive* by default and would shadow AUCTeX's own `TeX--completion-at-point` (which is the only source for project-local `\newcommand` macros that texlab doesn't see). The merged capf is set buffer-locally via `my/latex-capf` on `LaTeX-mode-hook`. Order matters: eglot first, then AUCTeX, then citar; `cape-file` and `cape-dabbrev` are appended as fallbacks.
- **PDF viewing** is wired in a `with-eval-after-load 'tex` block that sets `TeX-view-program-selection`/`-list` to PDF Tools and adds `TeX-revert-document-buffer` to `TeX-after-compilation-finished-functions`. This is intentionally lazy: `pdf-tools` is loaded on demand via the `:magic ("%PDF" . pdf-view-mode)` trigger when AUCTeX opens the output PDF. Don't move these settings into `pdf-tools`'s `:config` — they belong to AUCTeX.
- **PDF auto-revert race**: `global-auto-revert-mode` is on with a 1-second poll for source files. PDFs **must not** poll-revert — pdf-tools re-reads the file mid-render and races latexmk's progressive write, producing `"epdfinfo: Error opening …: PDF document is damaged"`. `init.el` disables auto-revert in `pdf-view-mode-hook` (with explicit `-1`, *not* a bare `auto-revert-mode` symbol — that toggles); the PDF buffer is instead reverted cleanly by `TeX-after-compilation-finished-functions` after latexmk exits. `revert-without-query` includes `\\.pdf\\'` to silence prompts on the rare path where revert does fire.
- **`pdf-view-use-scaling` is nil**: with it on, `pdf-cache-renderpage` accepts any cached PNG between 1× and 2× the desired width, so after a zoom/resize a stale wider render is reused and Cairo resamples it on every redraw (measured ~200 ms per scroll step vs ~4 ms). The frame scale factor on this X11 build is 1, so scaling has no visual benefit. If PDF scrolling gets laggy, check `(image-size (pdf-view-current-image) t)` against the PNG's native size.
- **No continuous scroll for PDFs**: `pdf-tools` runs page-by-page (`n`/`p` to advance). A previous setup used `image-roll` (`:vc` from `dalanicolai/image-roll.el`) to add smooth scrolling but it produced spurious `(wrong-type-argument overlayp nil)` errors from its `pre-redisplay` hook and was removed. `custom.el` still lists `image-roll` and `pdf-continuous-scroll-mode` under `package-vc-selected-packages` — leftover entries; harmless, but they'll re-fetch on a fresh install. Don't re-enable image-roll without first checking whether upstream has been actively maintained.
- **PDF window placement** is dynamic. A small system around `paul/pdf-display-mode` (a defvar holding `'side` or `'frame`) installs a `display-buffer-alist` entry matching `\\.pdf\\'`. Mode `'side` puts PDFs in a 50%-width right side window; mode `'frame` pops them into their own OS-level Emacs frame. `paul/toggle-pdf-display` (bound to `C-c P`) swaps modes and re-displays any visible PDFs under the new rule. `paul/jump-pdf` (bound to `C-c p`) toggles input focus between the current source buffer and a PDF buffer, including across frames via `select-frame-set-input-focus`. Editing the rules: `paul/--pdf-display-rule`. Editing the bindings: the two `global-set-key` calls at the end of the block.
- **Citations** have two paths: RefTeX's `C-c [` and **citar** (`citar-capf-setup` is on both `LaTeX-mode` and `org-mode` hooks for completion-at-point, and the merged capf above also calls `citar-capf` directly). `citar-bibliography` points at `~/bibliography.bib` — change this when the user's bib path differs.
- **Minibuffer stack**: vertico + marginalia + orderless + savehist + `consult` (search/jump) + `embark` (act-on-thing) + `embark-consult` glue. `orderless` is the primary `completion-styles` with a `file` override that falls back to basic + partial-completion (so file-path completion still feels right). consult bindings replace `C-x b`, `M-y`, `M-g g`, `M-g i`, and add `M-s l` / `M-s r`; embark-act is on `C-.`. `consult-ripgrep` needs `rg` on `PATH`.
- **`which-key`** is on globally — passive UX, just shows continuations after a prefix delay. No interactions with anything else.
- **`yasnippet`** runs as `yas-global-mode`, with `yasnippet-snippets` providing the bundled snippet pack (incl. LaTeX). User snippets live under `~/.emacs.d.latex/snippets/<mode>/`. `TAB` is the expansion key, which can collide with corfu's `TAB`; in practice yasnippet wins when at a snippet trigger and corfu wins otherwise.
- **`preview-latex`** ships with AUCTeX. `preview-scale-function` is set to `0.85` via `with-eval-after-load 'preview` to keep wide equations from overflowing the narrow source window (the side-window PDF would otherwise occlude them). Tune this number if equations are clipped (smaller) or hard to read (larger).
- **`gptel`** is configured with the Anthropic backend; `gptel-model` is currently `claude-sonnet-4-20250514`. Auth is via `auth-source` (`gptel-api-key-from-auth-source`), not a hardcoded key.
- **`claude-code-ide`** runs the Claude Code CLI in an in-Emacs terminal and speaks MCP back to Emacs (xref/imenu/project tools via `claude-code-ide-emacs-tools-setup`). Not on MELPA — installed via `:vc` from `manzaltu/claude-code-ide.el`. Terminal backend is `eat` (pure elisp) with `claude-code-ide-no-flicker` set to `t`. That flag exports `CLAUDE_CODE_NO_FLICKER=1`, which puts the Claude CLI into fullscreen (alternate-screen) rendering — the mode where scrolling and the mouse actually work and where the flicker / scroll-jump *and* the on-resize gibberish are addressed (full-frame repaint instead of streaming into native scrollback). `eat` is used rather than `vterm` because **eat forwards mouse events to the terminal app**, so the mouse wheel scrolls the transcript; `vterm` binds only `mouse-1` and cannot forward the wheel. `vterm` (libvterm C module) is kept installed as a fallback with more robust resize reflow — flip `claude-code-ide-terminal-backend` to `'vterm` if `eat` ever garbles on resize, and then scroll with the keyboard (PgUp/PgDn, `C-o` for a less-style transcript view with `/` search) since the wheel won't forward there. Fullscreen scroll extras: `CLAUDE_CODE_SCROLL_SPEED` (wheel-distance multiplier), `CLAUDE_CODE_DISABLE_MOUSE=1`, `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` (force classic renderer). See External dependencies for the vterm build deps. The CLI itself (`claude`) is an external dependency — `claude-code-ide-cli-path` overrides the lookup. Global keybinding `C-c C-'` opens the menu transient. Independent of the LaTeX stack; the buffer-name-based `display-buffer-alist` PDF rule does not match its terminal buffer names.
- **`proof-general`** is installed via plain `(use-package proof-general)` — no LaTeX-side wiring. Opening a `.ec` file autoloads `easycrypt-mode` and starts PG's proof-script / `*goals*` / `*response*` window layout. PG is mode-scoped and does not register a global capf, so corfu/cape work in proof buffers without explicit setup. Requires the `easycrypt` binary on `PATH`; pin per-project via `.dir-locals.el` setting `easycrypt-prog-name` if a wrapper is needed. The `\\.pdf\\'` `display-buffer-alist` rule does not match PG buffer names, so the PDF window system does not interfere.

## Daemon mode

This config is intended to be run as a systemd-managed Emacs daemon, not as a fresh `emacs` invocation per session. Cold init takes ~2.5 s on the Reform; the daemon amortizes that across all client frame opens. Direct `emacs --init-directory=~/.emacs.d.latex` still works for one-offs and for `emacs --debug-init` testing.

- **Service unit**: `~/.config/systemd/user/emacs-latex.service`. Enabled and autostarts via `default.target`. `ExecStart` is `/usr/local/bin/emacs --init-directory=%h/.emacs.d.latex --daemon=latex`.
- **Socket**: `/run/user/$(id -u)/emacs/latex`. Connect with `emacsclient -s latex -c [file]` (`-c` = new graphical frame, `-n` = fire-and-forget).
- **PATH exposure**: the service unit's `Environment=PATH=…` line is what makes `texlab`, `latexmk`, opam-installed proof assistants, etc. visible to eglot and AUCTeX. systemd user services do *not* inherit interactive shell PATH, so a tool installed via `cargo install` or `opam install` is invisible to eglot's `executable-find` without this line. Currently lists `~/.opam/default/bin`, `~/.cargo/bin`, `/usr/local/texlive/2026/bin/aarch64-linux`, `~/.local/bin`, plus the system defaults. When installing a new toolchain emacs needs, update this line and run `systemctl --user daemon-reload && systemctl --user restart emacs-latex`.

### First-frame initialization (`paul/--first-frame-init`)

The daemon starts headless — there is no graphical frame at the time `init.el` runs. Settings that depend on a real frame (face attributes like `:height`, theme loading, frame parameters not covered by `default-frame-alist`) must be deferred until a client frame actually exists, or they either silently no-op or attach to the daemon's invisible stub frame and never propagate to clients.

The pattern, near the top of `init.el`: put frame-dependent forms inside `paul/--first-frame-init`. The function is guarded by `paul/--first-frame-init-done` so it runs exactly once, and only on the first *graphical* frame (TTY clients via `emacsclient -t` are skipped). Registration is conditional on `(daemonp)` so the same code works in both daemon and non-daemon launches:

```elisp
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'paul/--first-frame-init)
  (paul/--first-frame-init))
```

When adding new frame-dependent setup, append to the function body, not to top-level `init.el`. Current content: just the default-face `:height 160` assignment.

### Companion launcher

`~/sysmgmt/launch-paper.sh` is a wofi-driven launcher (exposed via `~/.local/share/applications/launch-paper.desktop`) that:

1. Pops a wofi list of `~/research/*` subdirs containing a `.tex` file.
2. `systemctl --user start emacs-latex` defensively.
3. Spawns a sway workspace `N:paper-<choice>` in tabbed layout, where `N` is the lowest free workspace number in 1..10 (so `$mod+N` reaches it).
4. Spawns `emacsclient -s latex -n -c <paper-dir>/main.tex` into tab 1 and `alacritty --working-directory <paper-dir>` into tab 2.
5. Re-running on an already-open paper switches to its existing workspace by num rather than spawning duplicates.

The sway side requires `bindsym $mod+N workspace number N` (not bare `workspace N`) for `$mod+N` to match by num regardless of the `N:label` name format. Independent of this config's contents but documented here because failures of the launcher often show up as "the LSP can't find texlab" or similar — see PATH exposure above.

## External dependencies (not installed by Emacs)

- **`texlab`** — required for `eglot` to do anything useful in LaTeX. eglot will silently no-op if absent. **Do NOT `cargo install texlab`**: crates.io is frozen at 4.3.2 (the maintainers stopped publishing there — see the README), so `cargo install` silently pins you to a pre-5.0 build with worse completion (e.g. it indexes `\advA_{k}`/`\sid:` usages as bogus commands). Install the prebuilt binary from the [GitHub releases](https://github.com/latex-lsp/texlab/releases) (`texlab-aarch64-linux.tar.gz` on the Reform) into `~/.local/bin/texlab`, or `cargo install --git https://github.com/latex-lsp/texlab --locked --tag <vX.Y.Z>` to build from source. The service-unit PATH lists `~/.local/bin` *before* `~/.cargo/bin` precisely so a stray `cargo install` (4.3.2 → `~/.cargo/bin`) can't shadow the real binary. Currently on 5.25.1.
- **`epdfinfo`** — pdf-tools' helper, built on first launch via `M-x pdf-tools-install`. Needs libpng, poppler-glib, and a C toolchain on the system.
- **`latexmk`** — invoked by `auctex-latexmk` for the default build command.
- **`rg`** (ripgrep) — needed by `consult-ripgrep` (`M-s r`). Soft dep: that one command no-ops without it; everything else still works.
- **`easycrypt`** — required for Proof General to actually drive an EasyCrypt session. Install per the upstream instructions at https://www.easycrypt.info/. Without it, opening `.ec` files still enters `easycrypt-mode` (font-lock works) but `proof-assert-next-command` etc. will fail when PG tries to spawn the prover.
- **`claude`** (Claude Code CLI) — required for `claude-code-ide` to spawn a session. Install per https://claude.com/claude-code. Without it, `M-x claude-code-ide` errors out when it tries to launch the subprocess; everything else still works.
- **vterm C module** (`vterm-module.so`) — the `claude-code-ide` *fallback* terminal backend (the active one is `eat`; see the architecture note). Built automatically on first `(require 'vterm)` into `elpa/vterm-*/vterm-module.so` via cmake. Build deps: `cmake`, `gcc`/`cc`, `make`, and **`libtool-bin`** (Debian split `/usr/bin/libtool` out of the `libtool` package into `libtool-bin` — the `libtool` package alone ships only `libtoolize`, and the build fails at `cmake` configure with "libtool not found. Please install libtool"). Emacs must also be built with dynamic-module support (`module-file-suffix` non-nil — it is here, `.so`). The vendored libvterm is git-cloned from a mirror during the build, so first build needs network; alternatively install `libvterm-dev` and cmake will use the system libvterm and skip the libtool/vendored path entirely. If the module can't be built on some machine, set `claude-code-ide-terminal-backend` to `'eat` (pure elisp, no build).

## Conventions

- `custom.el` is the user's Customize-managed file (themes, package-vc selections). Don't move settings from `init.el` into it or vice versa unless asked — the split is intentional.
- `use-package-always-ensure` is `t`, so any new `use-package` block will auto-install from MELPA. Use `:ensure nil` for built-ins (see `savehist`).
- The `LaTeX-mode` hook list in the AUCTeX block is the canonical place to add new per-LaTeX-buffer behavior.
- `CHEATSHEET.md` is user-facing key reference. Keep it in sync if a new keybinding/workflow is added to `init.el`.

## Validating changes

There is no CI or test runner. After editing `init.el`:

1. **Daemon path (normal)**: `systemctl --user restart emacs-latex`. Use `journalctl --user -u emacs-latex` to surface init errors. First client frame after the restart eats the cold-start; subsequent client frames are instant again.
2. **Small tweak (no restart)**: open a client frame, `M-x eval-buffer` on the modified portion of `init.el`. Doesn't catch `:hook`/`:custom` ordering issues that only manifest at fresh init.
3. **Cold-test without the daemon**: `emacs --debug-init --init-directory=~/.emacs.d.latex` runs init synchronously and surfaces load errors. Useful to confirm `paul/--first-frame-init` fires correctly on the non-daemon code path before promoting changes to the running daemon.

For package issues: `M-x package-refresh-contents`, then `M-x package-upgrade-all` (Emacs 29+).
