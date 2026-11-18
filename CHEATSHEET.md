# LaTeX-in-Emacs Cheat Sheet

Notation: `C-` = Ctrl, `M-` = Alt/Meta, `S-` = Shift. `C-c C-c` means hit
Ctrl+c twice in a row (release between).

---

## which-key — discoverability

`which-key-mode` is on globally. After typing any prefix (e.g. `C-c
C-`), wait ~1s and a panel pops up listing every available
continuation. This is how you discover commands without hunting the
manual.

Customization:
- `which-key-idle-delay` — seconds before the panel appears (default 1.0).
- `which-key-popup-type` — `'side-window` (default), `'minibuffer`, `'frame`.
- `which-key-show-early-on-C-h` — set non-nil to show the panel
  immediately if you press `C-h` after a prefix (skip the wait).
- `which-key-sort-order` — `'which-key-key-order-alpha`,
  `'which-key-prefix-then-key-order`, etc.

---

## AUCTeX — editing & building

### Building & viewing
| Keys        | What it does                                                    |
|-------------|-----------------------------------------------------------------|
| `C-c C-c`   | Run the default command (LatexMk here) on the document/region. |
| `C-c C-a`   | Build **and** view in one go (`TeX-command-run-all`).          |
| `C-c C-v`   | View the compiled PDF.                                         |
| `C-c C-l`   | Open the compilation log buffer.                               |
| `C-c `` ` ``| Jump to the next LaTeX error (backtick).                        |
| `C-c C-k`   | Kill a running compilation.                                    |
| `C-c C-z`   | Fold the current section/environment.                          |
| `C-c C-r`   | Run a command on the active region (more explicit than `C-c C-c`). |
| `C-c C-c LaTeX RET` | Run plain `latex` once (skip latexmk) — handy for one-off debugging. |
| `C-c C-t C-p` | Toggle `TeX-PDF-mode` — switch between PDF and DVI output. |

Tip: `C-c C-c` on a selected region compiles just that region (useful for
isolating errors in a big document).

Customization:
- `TeX-engine` — `'default` (pdftex), `'luatex`, `'xetex`. Set
  per-file via `% !TEX program = lualatex` magic comment, or
  `(setq-local TeX-engine 'luatex)` via dir-locals.
- `TeX-command-default` — name of the command run by `C-c C-c`
  (currently `"LatexMk"`).
- `TeX-command-list` — full table of compile commands; add custom ones
  here (e.g. a build with `--shell-escape`).
- `TeX-save-query` — `nil` to auto-save before compile; `t` to prompt.

### Inserting structure
| Keys      | What it does                                  |
|-----------|-----------------------------------------------|
| `C-c C-e` | Insert an `\begin{…}…\end{…}` environment.    |
| `C-c C-s` | Insert a `\section{…}` (prompts for level).   |
| `C-c C-m` | Insert a macro (with argument prompts).       |
| `C-c C-j` | Insert `\item` (in itemize/enumerate envs).   |
| `C-c C-f` | Font helpers: `C-c C-f C-b` → `\textbf{}`, `C-f` → emph, `C-i` → italic, `C-t` → typewriter. |
| `C-c C-q` | Fill (reflow) the current paragraph / environment / section. |
| `C-c C-o C-f` | Toggle outline/folding minor mode.        |
| `C-c ]`   | Close current `\begin` (insert matching `\end`).  |
| `C-c *`   | Mark the current section.                     |
| `C-c .`   | Mark the current environment.                 |

### Navigation
| Keys        | What it does                                    |
|-------------|-------------------------------------------------|
| `C-M-a`     | Beginning of current environment.               |
| `C-M-e`     | End of current environment.                     |
| `C-M-h`     | Mark current LaTeX section (paragraph-aware).   |
| `M-g M-n`   | Next error (generic).                           |
| `M-g i`     | `consult-imenu` — jump to any section/label/macro definition. |

### preview-latex (inline equation rendering)

Ships with AUCTeX. Renders equations and other boxed content as
images directly in the source buffer.

| Keys              | What it does                                       |
|-------------------|----------------------------------------------------|
| `C-c C-p C-d`     | Preview the whole document (slow first time, cached after). |
| `C-c C-p C-p`     | Preview the chunk at point.                        |
| `C-c C-p C-r`     | Preview the region.                                |
| `C-c C-p C-s`     | Preview a single section.                          |
| `C-c C-p C-c C-p` | Clear preview at point.                            |
| `C-c C-p C-c C-d` | Clear all previews in document.                    |

Customization:
- `preview-scale-function` — numeric scale factor for preview images
  (currently `0.85` to fit narrow side-by-side windows). Smaller =
  smaller previews. Can also be a function.
- `preview-image-type` — `'png` (default), `'pdf`, `'dvipng`. PDF tends
  to look crisper at high DPI.
- `preview-default-preamble` — extra preamble injected only during
  preview generation (e.g. force left-aligned displays).
- `preview-auto-cache-preamble` — `t` to cache the preamble for faster
  repeated previews of the same document.

---

## RefTeX — labels, refs, citations, TOC

| Keys      | What it does                                                    |
|-----------|-----------------------------------------------------------------|
| `C-c (`   | Insert a `\label{…}` (smart: picks a sensible prefix).          |
| `C-c )`   | Insert a `\ref{…}` — pops up a selection buffer of all labels.  |
| `C-c [`   | Insert a `\cite{…}` — search BibTeX entries.                   |
| `C-c =`   | Show the **TOC** sidebar — navigate the whole document.         |
| `C-c &`   | Jump from a `\ref`/`\cite` to its definition (thing at point).  |
| `C-c /`   | Index entry (if you use `\index`).                              |
| `C-c -`   | Convert `\ref{x}` ↔ smart `\cref{x}` / `\Cref{x}` if cleveref enabled. |

In the TOC / selection buffer: `RET` to jump, `q` to quit, `g` to refresh.

Customization:
- `reftex-default-bibliography` — list of `.bib` files RefTeX should
  read (independent of citar's setting).
- `reftex-label-alist` — per-environment label prefix rules. Default
  gives `eq:`, `fig:`, `tab:`, etc.; extend for custom envs (e.g.
  add `("definition" ?d "def:" "~\\ref{%s}" t ("definition" "def."))`
  for a `definition` env keyed off `d`).
- `reftex-plug-into-AUCTeX` — already `t` here; controls whether
  AUCTeX's `\ref`/`\cite` insertions delegate to RefTeX.
- `reftex-cite-format` — `'default`, `'natbib`, `'biblatex`, etc.
  Determines what `C-c [` produces.

---

## cdlatex — fast math entry

`cdlatex-mode` is enabled automatically in `LaTeX-mode`.

### Inside math (`$…$`, `\[…\]`, `equation`, etc.)
| Keystroke    | Expands to                                            |
|--------------|-------------------------------------------------------|
| `` `a ``     | `\alpha` (backtick + letter → Greek).                 |
| `` `A ``     | `\forall` / capital Greek / operator (see `` `? ``).  |
| `` `? ``     | Show the full backtick-key reference.                 |
| `'a`         | Accent on `a` (apostrophe prefix → `\bar`, `\hat`, …).|
| `^`, `_`     | Auto-inserts `^{}` / `_{}` with point inside braces.  |
| `TAB`        | After `^{x}` jumps out of the braces.                 |
| `fr<TAB>`    | `\frac{}{}` with point in first slot, TAB to next.    |
| `sq<TAB>`    | `\sqrt{}`.                                            |
| `sum<TAB>`   | `\sum_{}^{}`.                                         |
| `lr(`        | `\left( \right)` around selection/point.              |

### Outside math
| Keystroke  | Expands to                                           |
|------------|------------------------------------------------------|
| `equ<TAB>` | `equation` environment.                              |
| `ali<TAB>` | `align` environment.                                 |
| `itm<TAB>` | `itemize` + first `\item`.                           |
| `enu<TAB>` | `enumerate` + first `\item`.                         |
| `C-c ?`    | Full list of cdlatex environment abbrevs.            |

Tip: hit `$` to toggle `$…$` around a region (or just around point).
Typing `$` immediately before an existing `$` skips over it instead of
inserting a new one (so closing inline math with `$`, or a muscle-memory
double-`$`, won't leave a stray third dollar). Customized via
`paul/cdlatex-dollar` in `init.el`.

Customization:
- `cdlatex-math-symbol-prefix` — character that triggers Greek/symbol
  expansion (default backtick `` ` ``). Change if backtick is reserved
  for another use.
- `cdlatex-math-modify-prefix` — accent prefix (default apostrophe `'`).
- `cdlatex-paired-parens` — string of paired delimiters that auto-pair
  in math mode (default `"$[{("`). Add `<` if you write a lot of
  `\langle…\rangle`.
- `cdlatex-command-alist` — custom abbrevs. Add your own `("foo" ...)`
  entries to expand `foo<TAB>` to whatever you want.
- `cdlatex-simplify-sub-super-scripts` — `t` to drop `{}` around
  one-character `^x` / `_x` (saves keystrokes on common cases).

---

## eglot + texlab — LSP intelligence

Eglot attaches automatically via the `LaTeX-mode` hook.

| Keys          | What it does                                          |
|---------------|-------------------------------------------------------|
| `M-.`         | Jump to definition (labels, citations, commands; falls back to project grep / `texdef` for macros texlab misses). |
| `M-,`         | Jump back.                                            |
| `M-?`         | Find references.                                      |
| `C-h .`       | Show documentation for symbol at point (eldoc).       |
| `M-x eglot-rename` | Rename a label across the project.               |
| `M-x eglot-code-actions` | Apply diagnostic fix-its.                  |
| `M-x eglot-format-buffer` | Format via texlab → latexindent.             |
| `M-x eglot-shutdown` / `M-x eglot` | Restart the LSP for a buffer.        |
| `M-x flymake-goto-next-error` | Next diagnostic (chktex warnings).    |
| `M-g n` / `M-g p` | Next / previous flymake diagnostic.            |

Check it's running: `M-x eglot-events-buffer` — you should see traffic with
`texlab`. If not, confirm `which texlab` on the shell.

Customization:
- `eglot-server-programs` — already pinned to `texlab` for LaTeX modes.
- `eglot-workspace-configuration` — pass texlab settings as Lisp.
  Example to tune chktex / latexindent:
  ```elisp
  (setq eglot-workspace-configuration
        '(:texlab (:chktex (:onOpenAndSave t)
                   :latexindent (:modifyLineBreaks t))))
  ```
  See `texlab --help` and the texlab settings docs for the full schema.
- `eglot-autoshutdown` — set `t` to kill the server when the last buffer
  using it closes.
- `eldoc-echo-area-use-multiline-p` — `t` for multi-line type info in the
  echo area; `'truncate-sym-name-if-fit` to keep it compact.

---

## pdf-tools — in-Emacs PDF viewer

After first install: run `M-x pdf-tools-install` once (compiles the helper).

### In a PDF buffer
| Keys      | What it does                                |
|-----------|---------------------------------------------|
| `n` / `p` | Next / previous page.                       |
| `SPC` / `S-SPC` | Scroll down / up.                     |
| `<right>` / `<left>` | Nudge the page right / left (a column at a time; same as `C-f` / `C-b`). |
| `C-x <` / `C-x >` | Jump a full page-width right / left (same as `C-<next>` / `C-<prior>`). |
| `<home>` / `<end>` | Snap to the page's left / right edge. |
| `+` / `-` | Zoom in / out.                              |
| `W`       | Fit to width. `H` fit height. `P` fit page. |
| `g` / `G` | First / last page.                          |
| `M-g g`   | Go to page number.                          |
| `s s`     | Slice (crop) to content — nice on big margins. |
| `s r`     | Reset slicing.                              |
| `I`       | Toggle midnight/dark mode.                  |
| `o`       | Outline (document TOC) side pane.           |
| `r`       | Revert/reload (rarely needed — we auto-revert on compile). |
| `q`       | Quit window.                                |
| `C-s`     | Incremental search through PDF text (pdf-isearch). |
| `M-x pdf-occur` | Search PDF text, results in a side buffer (RET to jump). |
| `M-x pdf-annot-add-highlight-markup-annotation` | Highlight selection. |
| `M-x pdf-annot-add-underline-markup-annotation` | Underline selection. |
| `M-x pdf-annot-add-text-annotation` | Sticky-note annotation at click point. |
| `M-x pdf-annot-list-annotations` | Side buffer of every annotation in the doc. |
| `M-x pdf-annot-delete` | Delete annotation at point.            |
| swipe     | Touchscreen scroll (custom; tune via `paul/pdf-view-touch-scroll-pixels-per-line`). |

**Pan a wide or zoomed-in page left/right:** `→` / `←` nudge right / left
by a column; `C-x <` / `C-x >` (same as `C-<next>` / `C-<prior>`) jump a
full screen-width right / left; `Home` / `End` snap to the left / right
edge. (These are the image-scroll commands, so they only do something
when the page is wider than the window — after `+` zoom or on a landscape
page.)

Tip: in a PDF buffer, hit `C-h m` to see the full active keymap —
pdf-tools binds many annotation commands under a prefix that varies
by version. `C-.` (embark) on a region also offers PDF actions.

### SyncTeX (jump between source and PDF)
- **Source → PDF:** put the point in `.tex`, hit `C-c C-v` — PDF jumps to
  that line.
- **PDF → Source:** click a line in the PDF (`C-mouse-1` on some setups) or
  `M-x pdf-sync-backward-search-mouse`. Point jumps back to the `.tex`.

### Customization
- `pdf-view-display-size` — `'fit-page`, `'fit-width`, `'fit-height`,
  or a number. The default after open.
- `pdf-view-resize-factor` — multiplier per `+`/`-` keypress (default 1.25).
- `pdf-view-use-scaling` — `t` for retina/HiDPI sharper rendering.
- `pdf-view-midnight-colors` — `(fg . bg)` cons used by `I` toggle.
- `pdf-annot-default-annotation-properties` — defaults for new
  highlights (color, opacity, label).
- Persist scroll/zoom across sessions: `M-x pdf-view-restore-mode`
  (saves to `~/.emacs.d.latex/pdf-view-restore`).

### PDF window placement (side vs. own frame)

Two display modes for the PDF buffer, switchable on the fly:

- **`side`** (default): PDF in a 50%-width window pinned to the right
  of the current frame. Good for side-by-side editing + preview.
- **`frame`**: PDF in its own OS-level Emacs frame. Good for a second
  monitor, full-screen reading, or any time you don't want the PDF
  eating half your editing area.

| Keys      | What it does                                            |
|-----------|---------------------------------------------------------|
| `C-c P`   | Toggle PDF display mode (side ↔ frame). Currently-visible PDFs redisplay in the new layout. |
| `C-c p`   | Jump focus between the current source buffer and the PDF. Works in either mode (raises and focuses the PDF frame in `frame` mode). |

Customization (in `init.el`):
- `paul/pdf-display-mode` — initial mode; set to `'side` or `'frame`
  before the rule is installed.
- The rules themselves live in `paul/--pdf-display-rule`. Tweak the
  side window width, slot, or frame parameters there. To make a
  popped-up frame open at a particular size, add e.g.
  `(pop-up-frame-parameters . ((width . 100) (height . 60)))` to the
  `'frame` branch.

### Send a PDF to the reMarkable tablet

Uploads the PDF in the current buffer to the reMarkable **cloud** via
[`rmapi`](https://github.com/ddvk/rmapi); the tablet then syncs it down
over wifi (no cable needed). Runs asynchronously, so Emacs doesn't block
during the upload.

| Keys      | What it does                                            |
|-----------|---------------------------------------------------------|
| `C-c r`   | (in a PDF buffer) Send the current PDF to the reMarkable cloud root. |
| `C-u C-c r` | Same, but prompt for the document name and destination folder. |

**Document naming.** rmapi has no rename-on-upload flag — the tablet
document name is taken from the uploaded file's basename. Since every
paper compiles to `main.pdf`, sending them raw would name every project's
document "main" and they'd collide. So the command stages a temp copy
named after the **project**: the direct child of `~/research`
(`paul/remarkable-project-root`) that contains the PDF, regardless of
depth — both `~/research/foo/main.pdf` and `~/research/foo/src/main.pdf`
give document "foo". PDFs outside that root fall back to their enclosing
directory's name. `C-u C-c r` lets you override the name per call.

Notes:
- **One-time setup:** run `rmapi` once in a shell and paste the code from
  https://my.remarkable.com/device/desktop/connect. This writes
  `~/.config/rmapi/rmapi.conf`; until it exists, `C-c r` fails with an
  auth error (output lands in the `*rmapi*` buffer).
- **Re-sending the same project** (same document name): controlled by
  `paul/rmapi-upload-mode` in `init.el`. Default `"--content-only"`
  replaces the existing document's PDF *in place*, keeping the document
  and its annotations (and creates it on first send). Set to `"--force"`
  to delete-and-recreate (loses annotations), or `nil` to error on a
  name clash.
- `rmapi put` won't create folders. Make one first with
  `rmapi mkdir /Papers` in a shell, then target it with `C-u C-c r`.
- The binary path is `paul/rmapi-program` in `init.el` (defaults to
  `~/go/bin/rmapi`, since the emacs daemon's PATH doesn't include it).
- On failure, the upload's stderr/stdout is shown in `*rmapi*`.
- Useful shell verbs: `rmapi ls`, `rmapi get <doc>`, `rmapi mkdir`,
  `rmapi stat <doc>`.

---

## citar — bibliographies

Set `citar-bibliography` in `init.el` to your `.bib` files.

| Command                       | What it does                            |
|-------------------------------|-----------------------------------------|
| `M-x citar-insert-citation`   | Pick entries (multi-select with `M-a`) and insert a `\cite{…}`. |
| `M-x citar-open`              | Open an entry's PDF / notes / URL.      |
| `M-x citar-open-notes`        | Jump to/create notes for an entry.      |
| `M-x citar-open-entry`        | Open the `.bib` entry itself.           |
| `M-x citar-copy-reference`    | Copy a formatted reference to kill-ring.|
| `M-x citar-open-files`        | Open just the attached PDF(s) for an entry. |
| `M-x citar-open-links`        | Open the URL/DOI for an entry.          |
| `M-x citar-insert-bibtex`     | Paste a full BibTeX entry into a `.bib`.|
| `M-x citar-refresh`           | Re-read all `.bib` files from disk.     |

Completion-at-point (`C-M-i` / TAB in a cite macro) also uses citar
because `citar-capf-setup` is on the hook.

RefTeX's `C-c [` still works and can be faster for quick citations;
citar shines when you want to see titles/authors at a glance or act on
the entry (open PDF, take notes).

Customization:
- `citar-bibliography` — list of `.bib` files (currently
  `'("~/bibliography.bib")`). Per-project: set in `.dir-locals.el`.
- `citar-library-paths` — directories citar scans for attached PDFs
  (matched by citation key as filename stem).
- `citar-notes-paths` — directories holding per-entry note files.
- `citar-templates` — alist controlling how entries appear in the
  selection UI and what `citar-copy-reference` produces. Override
  `:main` for the headline format, `:preview` for the multi-line view.
- `citar-symbols` — glyphs (file/link/note) shown alongside entries.
  Useful for spotting which entries have a PDF vs. just a record.

---

## In-buffer completion (corfu)

Pops up automatically after 1 char — type `\` and you'll see a list of
LaTeX macros (from texlab), narrowing as you type more letters. Inside
`\cite{…}` you'll get bib keys via citar; on labels/refs, texlab feeds
the list.

| Keys          | What it does                                          |
|---------------|-------------------------------------------------------|
| `TAB` / `S-TAB` | Next / previous candidate in the popup.            |
| `C-n` / `C-p` | Same — next / previous.                               |
| `RET`         | Insert the selected candidate.                        |
| `C-g`         | Dismiss the popup.                                    |
| `M-SPC`       | Insert a space without dismissing (orderless).        |
| `C-h`         | Show docs for the candidate at point.                 |

`orderless` filtering applies here too, so `tex bf` will match
`\textbf{}`.

---

## Minibuffer (vertico / marginalia / orderless)

| Keys      | What it does                                         |
|-----------|------------------------------------------------------|
| `C-n` / `C-p` | Next / previous candidate in the vertical list.  |
| `TAB`     | Insert current candidate into the minibuffer.        |
| `RET`     | Accept current candidate.                            |
| `M-RET`   | Accept exactly what you typed (ignore candidates).   |
| `C-j`     | Submit input as-is (useful for creating new files).  |

**orderless** means you can type space-separated fragments in any order:
`lat ins env` matches `LaTeX-insert-environment`. Prefix a fragment with
`!` to negate (`lat !obs` excludes anything matching `obs`).

**marginalia** shows extra info (keybinding, docstring, file size) next to
each candidate. Toggle annotation detail with `M-A` in the minibuffer.

In `find-file`: `C-l` deletes one path component back; type `~/` or `/`
mid-path to jump to home or root; `C-j` submits the literal text (handy
for creating a new file whose name partially matches an existing one).

Customization:
- `vertico-count` — visible candidates in the popup (default 10).
- `vertico-resize` — `t` for window auto-resize, `nil` for fixed size.
- `vertico-cycle` — wrap `C-n` past the bottom back to the top.
- `marginalia-align` — `'left`, `'center`, `'right` for annotation
  column alignment.
- `marginalia-annotators` — `marginalia-annotators-heavy` (default,
  more info) or `'light` (faster on slow machines).
- `orderless-matching-styles` — list of matchers tried per fragment.
  Default is reasonable; add `'orderless-flex` for very loose matching.

---

## consult — search & jump

| Keys        | What it does                                              |
|-------------|-----------------------------------------------------------|
| `C-x b`     | Switch buffer with previews and grouping.                 |
| `M-y`       | Browse the kill ring.                                     |
| `M-g g`     | Go to line (live preview as you scroll).                  |
| `M-g i`     | Jump to any imenu entry — section/label/theorem/macro def. |
| `M-g I`     | Same, across all open project buffers.                    |
| `M-s l`     | Fuzzy in-buffer search (alternative to isearch).          |
| `M-s r`     | ripgrep across the project (needs `rg` on PATH).          |

Most consult commands preview the candidate as you cycle (`C-n`/`C-p`).
`RET` commits, `C-g` aborts and snaps point/window back to where it was.

Within `consult-buffer`, type `b SPC` to narrow to buffers only,
`f SPC` to files, `p SPC` to project buffers, `RET` clears the narrow.
The narrow keys come from `consult-narrow-key`.

Customization:
- `consult-narrow-key` — chord that toggles narrowing (default `<`).
- `consult-preview-key` — when previews fire. `'any` = continuous
  (default); a key/list of keys = on-demand only (e.g. `"M-."`).
- `consult-async-min-input` — minimum chars before async commands like
  `consult-ripgrep` start running (default 3).
- `consult-line-start-from-top` — `t` if you want `M-s l` to start the
  search at buffer top instead of point.

---

## embark — act on the thing at point

`C-.` opens a context menu of actions for whatever is "at point" — a
buffer in `C-x b`, a file in find-file, a symbol in code, a candidate
in any vertico session. Think right-click menu, keyboard-driven.

| Keys       | What it does                                              |
|------------|-----------------------------------------------------------|
| `C-.`      | embark-act — show actions for thing at point/candidate.   |
| `C-h B`    | embark-bindings — list every binding currently in effect. |

Inside `embark-act`, type the action's key (e.g. `k` to kill a buffer,
`d` to delete a file, `c` to copy text, `i` to insert). Or hit `C-h`
right after `C-.` to list all available actions for the current target.

`embark-export` (`E` after `C-.`) dumps the entire candidate list of a
vertico session into a real, editable buffer. For `consult-ripgrep`,
this gives you a wgrep-compatible buffer where edits propagate back to
the source files — bulk renames across a paper become trivial.

Customization:
- `embark-prompter` — `embark-keymap-prompter` (chord-style "type a key")
  vs. `embark-completing-read-prompter` (vertico-style menu).
- `embark-quit-after-action` — alist controlling whether each action
  closes the minibuffer afterward.
- `embark-indicators` — list of UI elements shown while waiting for
  the action key (`'embark-mixed-indicator`, `'embark-verbose-indicator`).

---

## yasnippet — snippet expansion

`yas-global-mode` is on. Type a snippet's trigger and hit `TAB` to
expand. `yasnippet-snippets` ships a large pack including LaTeX
boilerplate (theorem envs, figure/tabular skeletons, etc.).

| Keys / Command                 | What it does                              |
|--------------------------------|-------------------------------------------|
| `TAB`                          | Expand snippet at point — or jump to next field inside an active snippet. |
| `S-TAB`                        | Jump to previous field in an active snippet. |
| `M-x yas-insert-snippet`       | Pick a snippet by name from a menu.       |
| `M-x yas-describe-tables`      | Show every snippet active in current mode. |
| `M-x yas-new-snippet`          | Author a new snippet.                     |
| `M-x yas-visit-snippet-file`   | Edit an existing snippet.                 |
| `M-x yas-reload-all`           | Re-scan snippet dirs after editing.       |

Snippets you author are saved under `~/.emacs.d.latex/snippets/<mode>/`
(per major mode). Inside snippet files, `$1`, `$2`, … are tab stops;
`${1:default}` gives a placeholder; `$0` is final cursor position.

### Custom LaTeX snippets (in `snippets/latex-mode/`)

| Trigger      | Expands to                                                  |
|--------------|-------------------------------------------------------------|
| `fpage<TAB>` | `\fpage{0.45}{ … }` — one framed minipage for a game.       |
| `hfpages<TAB>` | `\hfpages{0.45}{ … }{ … }` — two framed pages side by side. |
| `adva<TAB>`  | `\advA` (`\mathcal{A}`); wraps in `$…$` only outside math.  |
| `advb<TAB>`  | `\advB` (`\mathcal{B}`); math-aware like `adva`.            |
| `advc<TAB>`  | `\advC` (`\mathcal{C}`); math-aware like `adva`.            |

The `adv*` snippets use `texmathp` so they add `$…$` in text but not when
point is already in math. `\fpage`/`\hfpages` are the paper's own macros
(`envirs.tex`), not cryptocode's `\pseudocode`. Two bundled snippets are
deliberately disabled (key removed via same-uuid override): `b`→`\textbf{}`
and `fr`→`frame`, the latter so cdlatex's `fr`→`\frac{}{}` works.

Customization:
- `yas-snippet-dirs` — list of dirs searched. Add a per-project dir
  (e.g. `~/research/snippets/`) for shared lab/project snippets.
- `yas-triggers-in-field` — `t` to allow nested expansion (a snippet
  triggered inside another snippet's field).
- `yas-prompt-functions` — UI selection order. With vertico installed,
  `yas-completing-prompt` produces the right look.
- `yas-also-auto-indent-first-line` — `t` to indent the first line of
  expanded snippets.

Authoring tip: read the bundled snippets at
`~/.emacs.d/elpa/yasnippet-snippets-*/snippets/latex-mode/` for
patterns. Copy and tweak.

---

## Handy general Emacs commands

| Keys      | What it does                                        |
|-----------|-----------------------------------------------------|
| `C-x C-f` | Find file.                                          |
| `C-x b`   | Switch buffer.                                      |
| `C-x C-s` | Save.                                               |
| `C-x k`   | Kill buffer.                                        |
| `C-x 2` / `C-x 3` | Split window horizontally / vertically.    |
| `C-x 1`   | Keep only current window.                           |
| `C-x 0`   | Close current window.                               |
| `C-x o`   | Move focus to other window.                         |
| `M-x`     | Run command by name (with orderless matching!).     |
| `C-g`     | Abort current action — your "get me out of here".   |
| `C-h k`   | Describe key (press a keybinding to see what it does). |
| `C-h f`   | Describe function.                                  |
| `C-h v`   | Describe variable.                                  |
| `C-h m`   | Describe current major mode — lists its keys.       |

### Resizing windows

After a `C-x 2` / `C-x 3` split, these grow or shrink the **currently
selected** window, taking the space from (or handing it to) its
neighbor. Rule of thumb: side-by-side splits (`C-x 3`) want the width
keys; stacked splits (`C-x 2`) want the height keys.

| Keys        | What it does                                             |
|-------------|---------------------------------------------------------|
| `C-x }`     | Make it **wider** — `}` pushes the right edge out.       |
| `C-x {`     | Make it **narrower** — `{` pulls it in.                  |
| `C-x ^`     | Make it **taller** — `^` points up.                     |
| `M-x shrink-window` | Make it **shorter** — no default key; or a negative prefix, `C-u -5 C-x ^`. |
| `C-x -`     | Shrink the window to just fit its buffer's contents.    |
| `C-x +`     | **Balance** — equalize every window's size (the "reset"). |

- **Bigger steps:** a numeric prefix sets the amount — `C-u 10 C-x }`
  widens by 10 columns, `C-u 5 C-x ^` heightens by 5 lines. Bare keys
  nudge by 1.
- **Mouse:** drag the **mode line** up/down to resize height; drag the
  **vertical divider** between two side-by-side windows to resize width.

---

## Tips & tricks

- **Master file.** For multi-file projects, put
  `%%% TeX-master: "main.tex"` in a magic comment at the bottom of each
  sub-file so `C-c C-c` always builds the whole document.
- **`%` in ranges.** Select a region and `C-c C-c` to compile just that
  region — great for debugging a single equation.
- **Forward search everywhere.** `C-c C-v` in any source line jumps the
  open PDF to that spot, even for included files.
- **chktex on save.** Diagnostics from texlab's chktex show up
  automatically via flymake; `M-g n` walks them.
- **RefTeX + citar.** Both can insert `\cite`. Use `C-c [` for keyboard
  speed, `M-x citar-insert-citation` when you want to browse.
- **Preview math inline.** `C-c C-p C-p` previews the chunk at point;
  `C-c C-p C-d` previews the whole document; `C-c C-p C-c C-p` clears
  previews at point.
- **Folding.** `C-c C-o C-b` folds the whole buffer; `C-c C-o C-x`
  unfolds. Nice for navigating long documents.
- **Outline.** `M-x outline-minor-mode` + `C-c @` prefix gives you
  section-level collapse/expand.
- **Fast env rename.** Put point in a `\begin{foo}` and
  `M-x LaTeX-modify-environment` swaps it (and its matching `\end`)
  to another environment.
- **Bulk find-and-replace across the paper.** `M-s r` (consult-ripgrep)
  → narrow to the pattern → `C-.` → `E` (embark-export). The results
  buffer is editable; `M-x wgrep-change-to-wgrep-mode`, edit lines,
  `C-c C-c` to apply changes back to all source files at once.
  Invaluable for renaming a label/macro project-wide.
- **Jump to a theorem in 3 keys.** `M-g i` (consult-imenu) lists every
  section, `\label`, theorem, and `\newcommand` in the buffer. Type a
  fragment of the name, RET. Faster than `C-c =` for spot navigation.
- **Snippet for theorem boilerplate.** Type `theorem` and TAB — yasnippet
  expands `\begin{theorem}\label{thm:…}…\end{theorem}` with cursor
  jumps. Works for `figure`, `tabular`, `align`, etc.
- **Discover any package's keys.** `C-h B` (embark-bindings) lists every
  active binding in the current buffer's keymaps. Faster than digging
  through `C-h m`.

---

## claude-code-ide — Claude Code inside Emacs

Runs the `claude` CLI in an `eat` terminal buffer and exposes Emacs's
xref / imenu / project APIs to Claude via MCP, so Claude can navigate
the buffer / project the same way you do. Self-contained — no
LaTeX-stack interactions.

| Keys / Command                     | What it does                                  |
|------------------------------------|-----------------------------------------------|
| `C-c C-'`                          | Open the `claude-code-ide-menu` transient — start, stop, switch sessions, send region/buffer. |
| `M-x claude-code-ide`              | Start (or jump to) a Claude session for the current project. |
| `M-x claude-code-ide-stop`         | Kill the current project's Claude session.    |
| `M-x claude-code-ide-switch-to-buffer` | Pop to the running session's terminal.    |
| `M-x claude-code-ide-send-region`  | Send the active region as a prompt.           |

Requires the `claude` CLI on `PATH` (override with
`claude-code-ide-cli-path`). The terminal backend is `eat` with
`claude-code-ide-no-flicker` set to `t` — that puts the Claude CLI in
**fullscreen (alternate-screen) rendering**, which is what fixes the
erratic scrolling and the on-resize gibberish, and is the mode where the
mouse and scrolling actually work.

**Scrolling the transcript (fullscreen mode):**

| Keys / input        | What it does                                          |
|---------------------|-------------------------------------------------------|
| mouse wheel         | Scroll the conversation a few lines at a time.        |
| `PgUp` / `PgDn`     | Scroll up / down by half a screen.                    |
| `C-o`               | Toggle **transcript mode** — `less`-style navigation. |
| in transcript: `j`/`k`, `g`/`G`, `C-u`/`C-d`, `/` then `n`/`N` | line / top-bottom / half-page / search. |
| `Esc` or `q`        | Leave transcript mode.                                |

The mouse wheel works because `eat` (unlike `vterm`) forwards mouse
events to Claude. Tune wheel distance with the `CLAUDE_CODE_SCROLL_SPEED`
env var (1–20). If `eat` ever garbles on a window resize, set
`claude-code-ide-terminal-backend` to `'vterm` in `init.el` (rock-solid
resize, but then scroll with the keyboard above — vterm won't forward the
wheel; build deps for its C module: cmake + gcc + `libtool-bin`).

---

## magit — Git inside Emacs

`C-x g` from anywhere opens the **status buffer** — your home base. Almost
every magit command is one keystroke from there, and `?` shows the
context-sensitive transient menu.

### Status buffer essentials
| Keys      | What it does                                                  |
|-----------|---------------------------------------------------------------|
| `C-x g`   | Open `magit-status` for the current repo.                     |
| `?`       | Top-level transient: lists every action available here.       |
| `TAB`     | Expand/collapse the section at point (file diff, hunk, …).    |
| `n` / `p` | Next / previous section.                                      |
| `g`       | Refresh the status buffer.                                    |
| `q`       | Quit the magit window (buries it).                            |

### Stage, commit, push/pull
| Keys      | What it does                                                  |
|-----------|---------------------------------------------------------------|
| `s`       | Stage file/hunk/region at point.                              |
| `u`       | Unstage.                                                      |
| `k`       | Discard change at point (asks first).                         |
| `c c`     | Start a commit — opens a message buffer; `C-c C-c` to finish, `C-c C-k` to cancel. |
| `c a`     | Amend the last commit.                                        |
| `P p`     | Push to upstream (`P` opens push transient; second key picks target). |
| `F p`     | Pull from upstream.                                           |
| `f f`     | Fetch from a remote.                                          |

### Branches, log, diff
| Keys      | What it does                                                  |
|-----------|---------------------------------------------------------------|
| `b b`     | Checkout an existing branch.                                  |
| `b c`     | Create and checkout a new branch.                             |
| `l l`     | Log of current branch (`l` opens log transient).              |
| `l a`     | Log of all branches.                                          |
| `d d`     | Diff transient — compare working tree, index, refs.           |
| `M`       | Remote transient (add/rename/remove).                         |
| `z`       | Stash transient (`z z` push, `z p` pop).                      |

In the commit-message buffer: write the message, then `C-c C-c` commits,
`C-c C-k` aborts. In log/diff buffers: `RET` on a commit shows it; `q`
quits.

---

## Daemon mode & launch-paper workflow

The config runs inside a systemd-managed Emacs daemon. Client frames
connect via `emacsclient` and open in milliseconds (cold-start ~2.5 s
is paid once on login, not per file open).

### Starting / stopping the daemon

| Command                                          | What it does                            |
|--------------------------------------------------|-----------------------------------------|
| `systemctl --user start emacs-latex`             | Start (no-op if already running).       |
| `systemctl --user restart emacs-latex`           | Kill + restart — required after substantive `init.el` changes. |
| `systemctl --user stop emacs-latex`              | Stop (closes all client frames).        |
| `systemctl --user status emacs-latex`            | Health, PID, last-start time.           |
| `journalctl --user -u emacs-latex`               | Daemon logs (init errors, package failures). |
| `emacsclient -s latex --eval '(emacs-version)'`  | Quick liveness probe from the shell.    |
| `emacsclient -s latex -c [file]`                 | Open a new client frame, optionally visiting a file. |

### Opening a paper

`$mod+d` → "Launch paper..." in wofi → pick a paper from `~/research/`.
The launcher spawns a tabbed sway workspace containing an Emacs client
frame on `main.tex` plus an alacritty cd'd into the paper directory.
The workspace gets the lowest free number in 1..10, so e.g. `$mod+2`
flips you back to it.

Re-running the launcher on an already-open paper switches to its
existing workspace instead of spawning duplicates.

### After editing init.el

| Scope                                                  | How to apply                            |
|--------------------------------------------------------|-----------------------------------------|
| Small tweak (set a var, redefine a defun)              | `M-x eval-buffer` on init.el from a client frame. |
| Anything touching `use-package` / hooks / frame setup  | `systemctl --user restart emacs-latex`. |
| Want to debug an init error                            | `emacs --debug-init --init-directory=~/.emacs.d.latex` cold-runs synchronously. |

If a CLI tool (texlab, latexmk, a new LSP server, etc.) isn't found
even though `which X` works in the shell, it's almost certainly the
daemon's PATH missing the install dir. Edit the `Environment=PATH=…`
line in `~/.config/systemd/user/emacs-latex.service` and run
`systemctl --user daemon-reload && systemctl --user restart emacs-latex`.

---

## Config maintenance

- Reload init after small edits: `M-x eval-buffer` in `init.el`. For
  anything substantive, `systemctl --user restart emacs-latex` (see
  daemon section above).
- Upgrade packages: `M-x package-refresh-contents` then
  `M-x package-upgrade-all` (Emacs 29+). Restart the daemon afterward
  to pick up macro-level changes in updated packages.
- List installed: `M-x package-list-packages`.
- Look at a variable's value: `C-h v NAME RET`.
