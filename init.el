;;; init.el --- LaTeX-focused Emacs config -*- lexical-binding: t; -*-

;;; Package setup
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq package-install-upgrade-built-in t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;;; Custom file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;;; Basic UI
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(setq x-select-enable-clipboard t)
(setq x-super-keysym 'meta)
(setq inhibit-startup-message t)

;;; First-frame initialization (daemon-safe).
;;;
;;; Anything that depends on a real graphical frame existing — face
;;; attributes, themes, frame parameters not covered by
;;; `default-frame-alist' — has to defer until a frame actually exists.
;;; A `--daemon' has no graphical frame at startup; without this hook,
;;; such settings either silently fail or attach to the daemon's stub
;;; frame and never propagate to client frames (first client opens with
;;; the wrong font, etc.).
;;;
;;; Add frame-dependent setup inside `paul/--first-frame-init'. The
;;; guard ensures it runs exactly once, on the first *graphical* frame
;;; (TTY clients via `emacsclient -t' are ignored).
(defvar paul/--first-frame-init-done nil
  "Non-nil after `paul/--first-frame-init' has run once.")

(defun paul/--first-frame-init ()
  "Run frame-dependent setup once on the first graphical frame.
Daemon path: invoked via `server-after-make-frame-hook' (the new
client frame is selected at that point). Non-daemon path: called
directly at the end of this block."
  (unless paul/--first-frame-init-done
    (when (display-graphic-p)
      (setq paul/--first-frame-init-done t)
      (set-face-attribute 'default nil :height 160))))

(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'paul/--first-frame-init)
  (paul/--first-frame-init))

;;; autorevert to make it easier to edit taking turns with claude code
(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)        ; don't spam the minibuffer
(setq auto-revert-interval 1)         ; check every second

;; Silence the "PDF changed on disk, revert?" prompt — global-auto-revert
;; already reverts PDF buffers; this just stops the y/n confirmation.
(add-to-list 'revert-without-query "\\.pdf\\'")

;; PDFs must not revert mid-write: pdflatex truncates main.pdf and writes
;; it progressively, and a revert in that window shows raw bytes /
;; "PDF document is damaged". (`auto-revert-mode -1' does NOT help here —
;; global-auto-revert-mode watches the file regardless.) Instead, treat
;; the PDF as stale only once its tail holds the `%%EOF' trailer, which
;; pdfTeX writes last. This works wherever latexmk runs (C-c C-c, a
;; terminal, Claude); the final write fires another file-notify event,
;; so the complete file still reverts promptly.
(defun paul/--pdf-complete-p (file)
  "Non-nil if FILE ends with a PDF `%%EOF' trailer (i.e. is fully written)."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (let ((size (file-attribute-size (file-attributes file))))
      (and size (> size 0)
           (ignore-errors
             (insert-file-contents-literally
              file nil (max 0 (- size 1024)) size)
             (search-forward "%%EOF" nil t))))))

(defun paul/--pdf-stale-p (&optional noconfirm)
  "`buffer-stale-function' for PDFs: stale only once fully written."
  (and buffer-file-name
       (paul/--pdf-complete-p buffer-file-name)
       (buffer-stale--default-function noconfirm)))

(add-hook 'pdf-view-mode-hook
          (lambda () (setq-local buffer-stale-function #'paul/--pdf-stale-p)))

;;; which-key — pop up available keybinding continuations after a prefix.
;;; Massively helps with AUCTeX's many C-c C-* chords.
(use-package which-key
  :init (which-key-mode))

;;; Minibuffer stack
(use-package vertico
  :init (vertico-mode))

(use-package marginalia
  :init (marginalia-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package savehist
  :ensure nil
  :init (savehist-mode))

;;; consult — search/jump enhancements that pipe through vertico.
(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)        ; jump to section/label/theorem
         ("M-g I"   . consult-imenu-multi)  ; same, across project buffers
         ("M-s l"   . consult-line)         ; in-buffer fuzzy search
         ("M-s r"   . consult-ripgrep)))    ; project-wide grep

;;; embark — act on the candidate at point or in the minibuffer.
;;; C-. anywhere offers context-sensitive actions; in a vertico session
;;; it acts on the highlighted candidate (jump, copy, kill, …).
(use-package embark
  :bind (("C-."   . embark-act)
         ("C-h B" . embark-bindings)))

(use-package embark-consult
  :after (embark consult)
  :demand t
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;;; In-buffer completion popup (corfu) — feeds off the same capf backends
;;; that eglot/citar already register, so LaTeX macros (via texlab),
;;; \ref/\label, and \cite keys all show up.
(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-prefix 1)
  (corfu-auto-delay 0.1)
  (corfu-cycle t))

;;; cape — merge multiple completion-at-point sources. Needed because
;;; eglot's capf is "exclusive" by default and shadows AUCTeX's own
;;; parser, so project-local \newcommand macros (which AUCTeX's auto/
;;; cache knows about, but texlab does not) never reach the popup.
(use-package cape
  :after eglot
  :init
  (defun my/latex-capf ()
    ;; Every auto-popup is a texlab completion request, and texlab indexes
    ;; the whole bibliography (cryptobib is ~68 MB), so the global 1-char /
    ;; 0.1 s trigger pegs a core while typing. Throttle it in LaTeX only.
    (setq-local corfu-auto-prefix 3)
    (setq-local corfu-auto-delay 0.4)
    (setq-local completion-at-point-functions
                (list (cape-capf-super
                       #'eglot-completion-at-point
                       #'TeX--completion-at-point
                       #'citar-capf)
                      #'cape-file
                      #'cape-dabbrev)))
  (add-hook 'LaTeX-mode-hook #'my/latex-capf))

;;; Pin texlab as the LaTeX LSP server. Eglot ships entries for both
;;; texlab and digestif, so if both are on PATH it prompts each time.
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((latex-mode LaTeX-mode plain-tex-mode) . ("texlab"))))

;;; M-. fallback for TeX macros that texlab can't resolve.
;;; texlab (via eglot) finds most project \newcommand macros, but returns
;;; nothing for: (a) uses followed by `_' or `:' -- it lexes `\pk_i' as
;;; the expl3 name `\pk_i'; (b) macros defined by \DeclarePairedDelimiter;
;;; (c) package and kernel commands such as \gets.  When eglot's
;;; definition lookup comes back empty in a TeX buffer, fall back to a
;;; regex search of the document's files (master + \input/\include tree
;;; + local .sty), then of every .tex/.sty/.cls in the project, then to
;;; `texdef' run with the master file's \documentclass/\usepackage lines.
;;; Only the empty-result case changes: references (M-?), apropos, and
;;; every non-TeX eglot buffer behave exactly as before.
(defconst my/latex-def-commands
  '("newcommand" "renewcommand" "providecommand" "DeclareRobustCommand"
    "NewDocumentCommand" "RenewDocumentCommand" "ProvideDocumentCommand"
    "DeclareDocumentCommand" "NewCommandCopy"
    "DeclarePairedDelimiter" "DeclarePairedDelimiterX"
    "DeclarePairedDelimiterXPP" "DeclareMathOperator" "DeclareMathSymbol"
    "DeclareMathDelimiter" "DeclareMathAccent" "DeclareMathRadical"
    "DeclareTextCommand" "DeclareTextCommandDefault" "DeclareTextSymbol"
    "DeclareTextSymbolDefault" "def" "edef" "gdef" "xdef" "let" "chardef"
    "mathchardef")
  "Commands whose first argument is the control sequence they define.")

(defun my/latex-macro-name-at-point ()
  "Name (without backslash) of the TeX control word at point, or nil.
Stops at the first non-letter, so on `\\pk_i' this returns \"pk\"."
  (save-excursion
    (when (eq (char-after) ?\\) (forward-char 1))
    (skip-chars-backward "A-Za-z@")
    (when (and (eq (char-before) ?\\)
               (not (eq (char-before (1- (point))) ?\\))) ; `\\' linebreak
      (let ((beg (point)))
        (skip-chars-forward "A-Za-z@")
        (and (> (point) beg) (buffer-substring-no-properties beg (point)))))))

(defun my/latex--def-regexp (name)
  (concat "\\\\" (regexp-opt my/latex-def-commands)
          "\\*?[ \t]*{?[ \t]*\\\\" (regexp-quote name)
          "\\(?:[^A-Za-z@]\\|$\\)"))

(defun my/latex--commented-p (pos)
  "Non-nil if POS follows an unescaped % on its line."
  (save-excursion
    (goto-char pos)
    (let ((bol (line-beginning-position)) found)
      (while (and (not found) (search-backward "%" bol t))
        (unless (eq (char-before) ?\\) (setq found t)))
      found)))

(defun my/latex--defs-in-file (file regexp)
  "xref items for uncommented matches of REGEXP in FILE."
  (when (file-readable-p file)
    (let ((case-fold-search nil) items)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward regexp nil t)
          (let ((beg (match-beginning 0)))
            (unless (my/latex--commented-p beg)
              (save-excursion
                (goto-char beg)
                (push (xref-make
                       (string-trim (buffer-substring-no-properties
                                     (line-beginning-position)
                                     (line-end-position)))
                       (xref-make-file-location
                        file (line-number-at-pos) (current-column)))
                      items))))))
      (nreverse items))))

(defun my/latex--master ()
  (expand-file-name (or (ignore-errors (TeX-master-file "tex"))
                        (buffer-file-name))))

(defun my/latex--document-files (master)
  "MASTER plus the local files it pulls in via \\input, \\include, etc."
  (let ((dir (file-name-directory master)) (todo (list master)) seen)
    (while todo
      (let ((f (pop todo)))
        (unless (or (member f seen) (not (file-readable-p f)))
          (push f seen)
          (with-temp-buffer
            (insert-file-contents f)
            (goto-char (point-min))
            (while (re-search-forward
                    (concat "\\\\\\(input\\|include\\|subfile\\|usepackage"
                            "\\|RequirePackage\\)[ \t]*\\(?:\\[[^]]*\\]\\)?"
                            "[ \t]*{\\([^}]+\\)}")
                    nil t)
              (unless (my/latex--commented-p (match-beginning 0))
                (let ((pkg (member (match-string 1)
                                   '("usepackage" "RequirePackage"))))
                  (dolist (n (split-string (match-string 2) "," t "[ \t\n]+"))
                    (let ((cand (expand-file-name
                                 (cond (pkg (concat n ".sty"))
                                       ((file-name-extension n) n)
                                       (t (concat n ".tex")))
                                 dir)))
                      (when (file-readable-p cand) (push cand todo)))))))))))
    (nreverse seen)))

(defun my/latex--project-files ()
  (let ((pr (project-current nil)))
    (seq-filter (lambda (f) (string-match-p "\\.\\(?:tex\\|sty\\|cls\\)\\'" f))
                (if pr (project-files pr)
                  (directory-files-recursively default-directory "")))))

(defun my/latex--texdef-args (master)
  "`texdef' -c/-p arguments reproducing MASTER's preamble."
  (with-temp-buffer
    (insert-file-contents master)
    (let ((end (or (save-excursion
                     (goto-char (point-min))
                     (and (search-forward "\\begin{document}" nil t)
                          (match-beginning 0)))
                   (point-max)))
          args)
      (goto-char (point-min))
      (while (re-search-forward
              (concat "\\\\\\(documentclass\\|usepackage\\)[ \t]*"
                      "\\(\\[[^]]*\\]\\)?[ \t]*{\\([^}]+\\)}")
              end t)
        (unless (my/latex--commented-p (match-beginning 0))
          (let ((flag (if (equal (match-string 1) "documentclass") "-c" "-p"))
                (opts (or (match-string 2) "")))
            (dolist (n (split-string (match-string 3) "," t "[ \t\n]+"))
              (setq args (append args (list flag (concat opts n))))))))
      args)))

(defun my/latex--texdef-xrefs (name master)
  "Ask `texdef' where \\NAME comes from, given MASTER's preamble."
  (when (executable-find "texdef")
    (message "texdef: looking up \\%s..." name)
    (let* ((default-directory (file-name-directory master))
           (out (with-temp-buffer
                  (apply #'call-process "texdef" nil t nil
                         (append '("-t" "latex" "-F")
                                 (my/latex--texdef-args master)
                                 (list name)))
                  (buffer-string)))
           (re (my/latex--def-regexp name)))
      (message nil)
      (cond
       ((string-match "first defined in \"\\([^\"]+\\)\"" out)
        (let ((file (match-string 1 out)))
          (or (my/latex--defs-in-file file re)
              (list (xref-make (format "\\%s (defined in %s)" name
                                       (file-name-nondirectory file))
                               (xref-make-file-location file 1 0))))))
       ((string-match-p "is defined by (La)TeX" out)
        (or (seq-mapcat (lambda (f) (my/latex--defs-in-file f re))
                        (delq nil (mapcar (lambda (f)
                                            (let ((p (string-trim
                                                      (shell-command-to-string
                                                       (concat "kpsewhich " f)))))
                                              (and (not (string-empty-p p)) p)))
                                          '("fontmath.ltx" "latex.ltx"))))
            (list (xref-make (format "\\%s: TeX/LaTeX kernel" name)
                             (xref-make-bogus-location (string-trim out))))))))))

(defun my/latex-fallback-definitions (id)
  "Definitions of the TeX macro named by ID, or by the macro at point."
  (let ((name (if (and (stringp id) (string-prefix-p "\\" id))
                  (car (split-string (substring id 1) "[^A-Za-z@]"))
                (my/latex-macro-name-at-point))))
    (when (and name (not (string-empty-p name)))
      (let ((master (my/latex--master)) (re (my/latex--def-regexp name)))
        (or (seq-mapcat (lambda (f) (my/latex--defs-in-file f re))
                        (my/latex--document-files master))
            (seq-mapcat (lambda (f) (my/latex--defs-in-file f re))
                        (my/latex--project-files))
            (my/latex--texdef-xrefs name master))))))

(with-eval-after-load 'eglot
  (cl-defmethod xref-backend-definitions :around ((_backend (eql eglot)) id)
    (let* ((err nil)
           (defs (condition-case e (cl-call-next-method)
                   (error (setq err e) nil))))
      (or defs
          (and (derived-mode-p 'TeX-mode 'tex-mode)
               (my/latex-fallback-definitions id))
          (and err (signal (car err) (cdr err)))))))

;;; AUCTeX + RefTeX + cdlatex + eglot
(use-package tex
  :ensure auctex
  :hook ((LaTeX-mode . turn-on-reftex)
         (LaTeX-mode . turn-on-cdlatex)
         (LaTeX-mode . eglot-ensure)
         (LaTeX-mode . TeX-source-correlate-mode)
         (LaTeX-mode . TeX-PDF-mode))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-master nil)
  (TeX-source-correlate-start-server t)
  (reftex-plug-into-AUCTeX t))

(use-package cdlatex
  :config
  ;; cdlatex-dollar, when point is already inside $…$, INSERTS a closing
  ;; $ at point instead of stepping over the auto-inserted one — so a
  ;; muscle-memory "$$" lands you in "$$|$" (three dollars). Wrap it so a
  ;; $ typed immediately before an existing (unescaped) $ just skips over
  ;; it, the way electric-pair's skip-self would. All other cdlatex-dollar
  ;; behavior (region wrap, C-u for display math, escaped \$) is preserved
  ;; by falling through to the original.
  (defun paul/cdlatex-dollar (&optional arg)
    "Like `cdlatex-dollar', but skip over an existing closing $."
    (interactive "P")
    (if (and (eq (char-after) ?$)
             (not (cdlatex-number-of-backslashes-is-odd)))
        (forward-char 1)
      (cdlatex-dollar arg)))
  (define-key cdlatex-mode-map "$" #'paul/cdlatex-dollar))

;;; yasnippet — snippet expansion. Useful for theorem/figure boilerplate,
;;; preamble scaffolds, etc. cdlatex covers math symbols; yasnippet
;;; covers the structural stuff cdlatex doesn't.
(use-package yasnippet
  :init (yas-global-mode 1))

(use-package yasnippet-snippets
  :after yasnippet)

;;; preview-latex — inline equation rendering. Built into AUCTeX; the
;;; scale tweak below avoids wide equations overflowing a narrow source
;;; window (which then get hidden behind the side-window PDF).
(with-eval-after-load 'preview
  (setq preview-scale-function 0.85))

;;; latexmk as the default build command
(use-package auctex-latexmk
  :after tex
  :config
  (auctex-latexmk-setup)
  (setq auctex-latexmk-inherit-TeX-PDF-mode t
        TeX-command-default "LatexMk"))

;;; pdf-tools with SyncTeX
(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-tools-install :no-query)
  ;; With scaling on, pdf-cache accepts any cached render up to 2x the
  ;; desired width, so after a zoom or window resize a stale, wider PNG
  ;; gets reused and Cairo resamples it on every redraw (~200 ms per
  ;; scroll step on the Reform). The frame scale factor here is 1, so
  ;; scaling buys nothing; nil forces exact-width renders.
  (setq pdf-view-use-scaling nil))

;;; Touchscreen scrolling for pdf-view.
;;
;; Why we don't use Emacs's built-in touch-screen.el state machine:
;;
;; 1. pdf-tools tags touches over text regions with a `pdf-view-text-region'
;;    area prefix (via an image-overlay default keymap with `[area t]'),
;;    so the raw event becomes `[pdf-view-text-region touchscreen-begin]'.
;; 2. pdf-tools' own wildcard handler (`pdf-util-image-map-mouse-event-proxy')
;;    strips the prefix and unreads the event — but `unread-command-events'
;;    bypasses `function-key-map' translation, which is where Emacs installs
;;    the touch-screen state machine. So `touchscreen-scroll' events are
;;    never synthesized in pdf-view buffers.
;;
;; Workaround: handle the raw begin/update/end events ourselves, bind both
;; the bare and area-prefixed forms, track finger Y, and call pdf-view's
;; own line/page scrollers directly.

(defvar paul/pdf-view-touch-scroll-pixels-per-line 30
  "Finger-travel pixels per line of pdf-view scrolling.")

(defvar-local paul/pdf-view-touch-last-y nil
  "Last finger Y position during an active pdf-view touch, or nil.")

(defun paul/pdf-view-touch--y (event)
  "Recursively locate the first (X . Y) cons in EVENT and return Y.
Touchscreen event shapes vary by type and by translation path
(touchscreen-begin/end carry a POSN at position 1; touchscreen-update
carries a (POINT POSN APPROX) triple where POSN starts with a frame,
not a window; the area-prefixed translated paths shift things further).
Rather than enumerate every shape, walk the structure and grab the
first (NUMBER . NUMBER) cons we see — that is the cursor (X . Y)."
  (let ((stack (list event)))
    (catch 'found
      (while stack
        (let ((item (pop stack)))
          (cond
           ((and (consp item)
                 (numberp (car item))
                 (numberp (cdr item)))
            (throw 'found (cdr item)))
           ((consp item)
            (push (cdr item) stack)
            (push (car item) stack)))))
      nil)))

(defun paul/pdf-view-touch-begin (event)
  "Begin tracking a touch in pdf-view."
  (interactive "e")
  (setq paul/pdf-view-touch-last-y (paul/pdf-view-touch--y event)))

(defun paul/pdf-view-touch-update (event)
  "Scroll pdf-view in response to finger motion."
  (interactive "e")
  (let ((y (paul/pdf-view-touch--y event)))
    (when (and paul/pdf-view-touch-last-y y pdf-view-roll-minor-mode)
      ;; Continuous mode scrolls by pixels: follow the finger exactly.
      (pdf-roll-scroll-forward (- paul/pdf-view-touch-last-y y) nil t)
      (setq paul/pdf-view-touch-last-y y))
    (when (and paul/pdf-view-touch-last-y y (not pdf-view-roll-minor-mode))
      (let* ((dy        (- y paul/pdf-view-touch-last-y))
             (threshold paul/pdf-view-touch-scroll-pixels-per-line))
        (when (>= (abs dy) threshold)
          (let ((lines (/ (abs dy) threshold)))
            ;; Finger moves down (dy > 0) → reveal earlier content (scroll back).
            ;; Finger moves up   (dy < 0) → reveal later content   (scroll forward).
            (if (> dy 0)
                (pdf-view-previous-line-or-previous-page lines)
              (pdf-view-next-line-or-next-page lines))
            ;; Advance the anchor by the consumed delta; carry the remainder.
            (setq paul/pdf-view-touch-last-y
                  (+ paul/pdf-view-touch-last-y
                     (* (if (> dy 0) 1 -1) lines threshold)))))))))

(defun paul/pdf-view-touch-end (_event)
  "End touch tracking in pdf-view."
  (interactive "e")
  (setq paul/pdf-view-touch-last-y nil))

(defun paul/pdf-view-install-touch-bindings ()
  "Install touchscreen bindings in the current PDF buffer's local map.
Must run buffer-locally: pdf-tools installs its
`[pdf-view-text-region t]' wildcard via `local-set-key', which
ends up in a per-buffer keymap that shadows `pdf-view-mode-map'.
We have to put our specific bindings into that same buffer-local
map so they out-rank the wildcard for our three event symbols."
  (dolist (binding '((touchscreen-begin  . paul/pdf-view-touch-begin)
                     (touchscreen-update . paul/pdf-view-touch-update)
                     (touchscreen-end    . paul/pdf-view-touch-end)))
    (let ((ev (car binding))
          (fn (cdr binding)))
      (local-set-key (vector ev) fn)
      (local-set-key (vector 'pdf-view-text-region ev) fn))))

(add-hook 'pdf-view-mode-hook #'paul/pdf-view-install-touch-bindings)

;;; Continuous scroll via pdf-tools' own `pdf-view-roll-minor-mode'
;;; (pdf-roll.el, shipped with pdf-tools; marked experimental). This is
;;; NOT the old external image-roll package, which was removed after
;;; `(wrong-type-argument overlayp nil)' bursts from its pre-redisplay
;;; hook and "PDF document is damaged" errors. The latter were really
;;; mid-write auto-reverts, now prevented by `paul/--pdf-stale-p'.
;;; Measured ~18 ms per 3-line scroll step on the Reform.
;;; `M-x pdf-view-roll-minor-mode' toggles it per buffer.
(add-hook 'pdf-view-mode-hook #'pdf-view-roll-minor-mode)

;; Wire AUCTeX to pdf-tools regardless of load order. These forms reference
;; pdf-tools functions but don't need pdf-tools loaded at the time they run —
;; pdf-tools loads on demand when AUCTeX opens the output PDF.
(with-eval-after-load 'tex
  (setq TeX-view-program-selection '((output-pdf "PDF Tools"))
        TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view))
        TeX-after-compilation-finished-functions
        #'TeX-revert-document-buffer))

;;; Dynamic PDF window placement.
;; Two display modes:
;;   'side  — PDF in a 50%-width right side window (the default).
;;   'frame — PDF in its own OS-level Emacs frame (good for second
;;            monitor, or when you want to read full-screen).
;; C-c P toggles the mode; visible PDFs redisplay in the new layout.
;; C-c p jumps focus between the most recent source buffer and the
;; PDF buffer, and works whether the PDF is a window in this frame
;; or a window in a different frame.

(defvar paul/pdf-display-mode 'side
  "Where PDFs appear: `side' (right side window) or `frame' (own frame).")

(defun paul/--pdf-display-rule ()
  "Return the `display-buffer-alist' entry for the current PDF mode."
  (pcase paul/pdf-display-mode
    ('side  '("\\.pdf\\'"
              (display-buffer-reuse-window display-buffer-in-side-window)
              (side . right) (slot . 0) (window-width . 0.5)))
    ('frame '("\\.pdf\\'"
              (display-buffer-reuse-window display-buffer-pop-up-frame)
              (reusable-frames . visible)))))

(defun paul/--install-pdf-rule ()
  "Replace any existing PDF rule in `display-buffer-alist' with the current one."
  (setq display-buffer-alist
        (cons (paul/--pdf-display-rule)
              (cl-remove-if (lambda (entry) (equal (car entry) "\\.pdf\\'"))
                            display-buffer-alist))))

(defun paul/toggle-pdf-display ()
  "Toggle PDF display between side window and own frame.
Tear down any visible PDF presentation and re-display under the new
rule, so the change takes effect immediately."
  (interactive)
  (setq paul/pdf-display-mode
        (if (eq paul/pdf-display-mode 'side) 'frame 'side))
  (paul/--install-pdf-rule)
  (dolist (buf (buffer-list))
    (let ((f (buffer-file-name buf)))
      (when (and f (string-match-p "\\.pdf\\'" f))
        (dolist (win (get-buffer-window-list buf nil t))
          (let ((frame (window-frame win)))
            (cond
             ;; was a side window — just delete the window
             ((window-parameter win 'window-side)
              (delete-window win))
             ;; was its own frame, separate from the selected one — kill the frame
             ((and (frame-live-p frame)
                   (not (eq frame (selected-frame)))
                   (= 1 (length (window-list frame))))
              (delete-frame frame))
             ;; otherwise just delete the window if there's another in this frame
             ((> (length (window-list frame)) 1)
              (delete-window win)))))
        (display-buffer buf))))
  (message "PDF display: %s" paul/pdf-display-mode))

(defun paul/jump-pdf ()
  "Toggle focus between the current source buffer and a PDF buffer.
Works whether the PDF is in a side window or a separate frame."
  (interactive)
  (let* ((cur (buffer-file-name))
         (in-pdf (and cur (string-match-p "\\.pdf\\'" cur)))
         (target (cl-find-if (lambda (b)
                               (let ((f (buffer-file-name b)))
                                 (and f
                                      (if in-pdf
                                          (not (string-match-p "\\.pdf\\'" f))
                                        (string-match-p "\\.pdf\\'" f)))))
                             (buffer-list))))
    (if (not target)
        (message "No %s buffer to jump to."
                 (if in-pdf "source" "PDF"))
      (let ((win (get-buffer-window target t)))
        (unless win
          (setq win (display-buffer target)))
        (when win
          (select-frame-set-input-focus (window-frame win))
          (select-window win))))))

(paul/--install-pdf-rule)

(global-set-key (kbd "C-c p") #'paul/jump-pdf)
(global-set-key (kbd "C-c P") #'paul/toggle-pdf-display)

;;; Send the current PDF to a reMarkable tablet via rmapi.
;;
;; rmapi (https://github.com/ddvk/rmapi) talks to the reMarkable *cloud*;
;; the tablet then pulls the file over wifi. One-time device registration
;; — run `rmapi' once and paste the code from
;; https://my.remarkable.com/device/desktop/connect — writes
;; ~/.config/rmapi/rmapi.conf. Until that exists, uploads fail with an
;; auth error.
;;
;; Naming: rmapi has NO rename-on-upload option — the tablet document name
;; is taken verbatim from the uploaded file's basename (rmapi's
;; `DocPathToName' in put.go). Every paper here compiles to `main.pdf', so
;; uploading them as-is would name every project's document "main", and
;; they'd collide on the tablet. So we stage a temp copy named after the
;; *project*: the direct child of `paul/remarkable-project-root'
;; (~/research) that contains the PDF — so both ~/research/foo/main.pdf and
;; ~/research/foo/src/main.pdf yield document "foo". PDFs outside that root
;; fall back to their enclosing directory's name. Override per-call with a
;; prefix argument.
;;
;; Re-uploads of the *same* project (same name) are handled by
;; `paul/rmapi-upload-mode' (default --content-only: replace the existing
;; document's PDF in place, keeping it and its annotations; create if
;; absent). This is orthogonal to the cross-project naming above.
;;
;; PATH note: rmapi lives in ~/go/bin, which is NOT on the systemd emacs
;; daemon's PATH (user services don't inherit the interactive shell PATH —
;; see CLAUDE.md "PATH exposure"). So `executable-find' returns nil under
;; the daemon and we fall back to the absolute path.
(defvar paul/rmapi-program
  (or (executable-find "rmapi")
      (expand-file-name "~/go/bin/rmapi"))
  "Path to the rmapi executable used to upload PDFs to the reMarkable cloud.")

(defvar paul/rmapi-upload-mode "--content-only"
  "How `paul/remarkable-send-pdf' handles an existing same-named document.
One of:
  \"--content-only\" — replace the existing document's PDF in place,
                       preserving annotations; create it if absent (default).
  \"--force\"        — delete the existing document and upload a fresh one
                       (loses annotations).
  nil                — plain upload; error if the name already exists.")

(defvar paul/remarkable-project-root (expand-file-name "~/research/")
  "Root under which each project lives in its own subdirectory.
`paul/remarkable-document-name' names the tablet document after the direct
child of this directory that contains the PDF, regardless of how deep the
PDF sits (e.g. a `src/' subdir). PDFs outside this root fall back to their
enclosing directory's name.")

(defun paul/remarkable-document-name (file)
  "Return the reMarkable document name for FILE.
If FILE is under `paul/remarkable-project-root', use the direct child of
that root containing FILE (so .../foo/main.pdf and .../foo/src/main.pdf
both give \"foo\"). Otherwise fall back to FILE's enclosing directory name."
  (let* ((file (expand-file-name file))
         (root (file-name-as-directory
                (expand-file-name paul/remarkable-project-root))))
    (if-let* (((string-prefix-p root file))
              (rel (substring file (length root)))
              ;; require an actual project subdir, not a PDF sitting in root
              ((file-name-directory rel)))
        (car (split-string rel "/" t))
      (file-name-nondirectory
       (directory-file-name (file-name-directory file))))))

(defun paul/remarkable-send-pdf (&optional ask)
  "Upload the current buffer's PDF to the reMarkable cloud via rmapi.
The tablet document is named after the enclosing project directory (see
`paul/remarkable-document-name'), not the file, so per-project `main.pdf's
don't collide. Runs asynchronously; the result is reported in the echo
area, with rmapi's output left in the *rmapi* buffer on failure.

With a prefix argument ASK, prompt for both the document name and the
destination cloud folder (which must already exist — create one with
`rmapi mkdir /Foo')."
  (interactive "P")
  (let ((file (buffer-file-name)))
    (unless file
      (user-error "This buffer is not visiting a file"))
    (unless (string-match-p "\\.pdf\\'" file)
      (user-error "Not a PDF file: %s" file))
    (unless (file-executable-p paul/rmapi-program)
      (user-error "rmapi not found at %s — set `paul/rmapi-program'"
                  paul/rmapi-program))
    (let* ((default-name (paul/remarkable-document-name file))
           (docname (if ask
                        (read-string "reMarkable document name: " default-name)
                      default-name))
           (folder  (if ask (read-string "reMarkable folder: " "/") "/"))
           ;; rmapi derives the doc name from the basename, so stage a copy
           ;; literally named <docname>.pdf in a private temp dir.
           (tmpdir  (make-temp-file "rmapi-send-" t))
           (staged  (expand-file-name (concat docname ".pdf") tmpdir))
           (buf     (get-buffer-create "*rmapi*")))
      (copy-file file staged t)
      (with-current-buffer buf (erase-buffer))
      (message "reMarkable: uploading %s …" docname)
      (make-process
       :name "rmapi-put"
       :buffer buf
       :command (append (list paul/rmapi-program "put")
                        (and paul/rmapi-upload-mode
                             (list paul/rmapi-upload-mode))
                        (list staged folder))
       :noquery t
       :sentinel
       (lambda (proc _event)
         (when (memq (process-status proc) '(exit signal))
           (ignore-errors (delete-directory tmpdir t))
           (if (zerop (process-exit-status proc))
               (message "reMarkable: sent %s → %s" docname folder)
             (message "reMarkable: FAILED to send %s (see *rmapi*)" docname)
             (display-buffer buf))))))))

(with-eval-after-load 'pdf-view
  (define-key pdf-view-mode-map (kbd "C-c r") #'paul/remarkable-send-pdf))

;;; Citar for bibliography
(use-package citar
  :custom
  ;; Point this at your .bib file(s):
  (citar-bibliography '("~/bibliography.bib"))
  :hook ((LaTeX-mode . citar-capf-setup)
         (org-mode   . citar-capf-setup)))

;;; Notes:
;;;   texlab must be installed separately for eglot to pick it up.
;;;     Arch:   pacman -S texlab
;;;     Cargo:  cargo install --locked texlab
;;;     Or grab a binary from https://github.com/latex-lsp/texlab/releases
;;;   On first launch, `M-x pdf-tools-install' will compile the epdfinfo
;;;   helper — needs libpng, poppler-glib, and build tools on your system.

(use-package gptel
  :ensure t
  :config
  (setq gptel-model 'claude-sonnet-4-20250514
        gptel-backend (gptel-make-anthropic "Claude"
                        :stream t
                        :key #'gptel-api-key-from-auth-source)))

;;; vterm — libvterm-backed terminal, kept installed as an alternate
;;; claude-code-ide backend. It handles window-resize reflow more
;;; robustly than eat, but it does NOT forward mouse events to the
;;; terminal app (it binds only `mouse-1'), so the mouse wheel can't
;;; scroll a full-screen TUI like the Claude CLI. Switch to it (flip
;;; `claude-code-ide-terminal-backend' to 'vterm) if eat ever garbles on
;;; resize; you then scroll with the keyboard (PgUp/PgDn, C-o) since the
;;; wheel won't forward. Needs a one-time C-module build (cmake + gcc +
;;; make + libtool-bin; see CLAUDE.md → External dependencies).
(use-package vterm)

;;; eat — pure-elisp terminal emulator; the claude-code-ide backend.
;;; Chosen over vterm because eat forwards mouse events to the terminal
;;; app, so the mouse wheel scrolls the Claude transcript once Claude is
;;; in fullscreen/mouse mode (see `claude-code-ide-no-flicker' below).
(use-package eat)

;;; claude-code-ide — runs the Claude Code CLI inside Emacs and exposes
;;; Emacs's xref/imenu/project APIs to Claude over MCP. Not on MELPA;
;;; pulled directly from upstream via :vc. Requires the `claude' binary
;;; on PATH (set `claude-code-ide-cli-path' if it lives elsewhere).
;;; `C-c C-'' is global on purpose — useful from any buffer, not just LaTeX.
;;;
;;; `claude-code-ide-no-flicker' t sets CLAUDE_CODE_NO_FLICKER=1, which
;;; puts the Claude CLI into fullscreen (alternate-screen) rendering.
;;; That is the mode where scrolling and the mouse actually work and
;;; where the flicker / scroll-jump ("squirrely scrolling") is fixed; its
;;; full-frame repaint should also cure the on-resize gibberish. Scroll
;;; with the mouse wheel (via eat's mouse forwarding), PgUp/PgDn, or C-o
;;; for a less-style transcript view with `/' search. The classic
;;; (non-fullscreen) renderer ignores the mouse and streams into native
;;; scrollback, which is what caused the erratic scrolling to begin with.
(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c C-'" . claude-code-ide-menu)
  :custom
  (claude-code-ide-terminal-backend 'eat)
  (claude-code-ide-no-flicker t)
  :config
  (claude-code-ide-emacs-tools-setup))

;;; claude-code-ide always roots a session at the VC/project root (it calls
;;; `project-root' on `project-current'). But `claude' keys its sessions by
;;; the directory it is launched in, so when you work from a subdirectory
;;; (e.g. a paper's `src/') the session is filed under that subdir — and
;;; later `-c'/`-r' from the package look at the *repo-root* project instead,
;;; so the subdir's sessions never show up. This command launches
;;; claude-code-ide rooted at a directory you choose (default: the current
;;; buffer's), by binding `project-find-functions' to nil so project
;;; detection falls back to `default-directory'. No prefix starts fresh;
;;; `C-u' continues the most recent conversation there (claude -c); `C-u C-u'
;;; opens the resume picker for that directory (claude -r).
(defun paul/claude-code-ide-in-dir (dir &optional mode)
  "Start `claude-code-ide' rooted at DIR, ignoring project detection.
Interactively, prompt for DIR (defaulting to `default-directory') and read
MODE from the prefix argument: nil starts a new session, a single `C-u'
selects `continue', and a double `C-u' selects `resume' (the session picker)."
  (interactive
   (list (read-directory-name "Claude root: " nil nil t)
         (pcase current-prefix-arg
           ('(4)  'continue)
           ('(16) 'resume)
           (_     nil))))
  (require 'claude-code-ide)
  (require 'project)
  (let ((default-directory (file-name-as-directory (expand-file-name dir)))
        (project-find-functions nil))
    (pcase mode
      ('continue (claude-code-ide-continue))
      ('resume   (claude-code-ide-resume))
      (_         (claude-code-ide)))))

;;; Soft-wrap LaTeX/TeX source buffers while a claude-code-ide window is
;;; visible (its side pane narrows the source window and long lines run
;;; off-screen), and unwrap when it goes away. Only buffers we toggled
;;; ourselves get reverted, so a manually-enabled `visual-line-mode' is
;;; left alone. claude-code-ide exposes no start/stop hook, so we watch
;;; `window-configuration-change-hook' and only act on transitions.
(defvar paul/--claude-wrap-toggled nil
  "Buffers in which we enabled `visual-line-mode' for the Claude side window.")

(defvar paul/--claude-window-prev-visible nil
  "Previous visibility of any claude-code-ide window, for edge detection.")

(defun paul/--claude-window-visible-p ()
  (seq-some (lambda (w)
              (string-prefix-p "*claude-code["
                               (buffer-name (window-buffer w))))
            (window-list nil 'no-mini)))

(defun paul/--claude-wrap-target-p (buf)
  (with-current-buffer buf
    (derived-mode-p 'LaTeX-mode 'latex-mode 'tex-mode)))

(defun paul/--claude-wrap-watch ()
  (let ((now (paul/--claude-window-visible-p)))
    (unless (eq (and now t) (and paul/--claude-window-prev-visible t))
      (setq paul/--claude-window-prev-visible now)
      (if now
          (dolist (buf (buffer-list))
            (when (and (paul/--claude-wrap-target-p buf)
                       (not (buffer-local-value 'visual-line-mode buf)))
              (with-current-buffer buf (visual-line-mode 1))
              (push buf paul/--claude-wrap-toggled)))
        (dolist (buf paul/--claude-wrap-toggled)
          (when (buffer-live-p buf)
            (with-current-buffer buf (visual-line-mode -1))))
        (setq paul/--claude-wrap-toggled nil)))))

(add-hook 'window-configuration-change-hook #'paul/--claude-wrap-watch)

;;; Fix claude-code-ide's resize filter (workaround for claude-code#1422).
;;; Upstream decides whether to forward a resize to the pty by checking a
;;; per-window cached width over *all* claude windows in the selected frame.
;;; With two sessions open, the adjustment for session A updates the cache
;;; for session B's window, so B's own adjustment then looks "unchanged" and
;;; is suppressed -- after eat has already resized its display. Result: eat
;;; draws at the new width, the pty still reports the old one, and the
;;; Claude TUI is garbled. Decide per process instead, against the width we
;;; last actually sent to that pty.
(with-eval-after-load 'claude-code-ide
  (defun claude-code-ide--terminal-reflow-filter (original-fn &rest args)
    "Forward a resize to the pty only if this process's width changed."
    (let* ((process (car args))
           (size (apply original-fn args)))
      (cond
       ((or (null size)
            (not (processp process))
            (not (claude-code-ide--session-buffer-p (process-buffer process))))
        size)
       ;; Scrolling/copying in the terminal: hold off; don't record, so the
       ;; next window change after leaving scroll mode forwards the size.
       ((with-current-buffer (process-buffer process)
          (claude-code-ide--terminal-scroll-mode-active-p))
        nil)
       ;; Height-only change: suppress (the upstream #1422 workaround).
       ((eql (car size) (process-get process 'paul/claude-sent-width))
        nil)
       (t
        (process-put process 'paul/claude-sent-width (car size))
        size)))))

;;; `transient' must be loaded from MELPA *before* magit. Emacs ships a
;;; built-in transient that is older than what magit requires; if it gets
;;; loaded first (via autoloads or another package), magit's attempt to
;;; redefine `transient--init-suffix-key' as a `cl-defgeneric' fails with
;;; "already defined as something else than a generic function".
(use-package transient
  :ensure t)

(use-package magit
  :ensure t
  :after transient)

;;; Proof General — Emacs interface for interactive proof assistants.
;;; Used here for EasyCrypt: opening a `.ec' file autoloads
;;; `easycrypt-mode' and starts the PG machinery on demand.
;;; Self-contained — no global keybindings, no interaction with the
;;; LaTeX stack. corfu works in proof buffers without extra wiring.
;;; Requires the `easycrypt' binary on PATH; set `easycrypt-prog-name'
;;; via Customize if it lives elsewhere.
(use-package proof-general)

;;b elow: maybe a solution to l-just eqn previews in emacs/auctex
;;(add-to-list 'preview-default-preamble
;;             "\\ifPreview
;;  \\usepackage{nccmath}
;;  \\everydisplay{\\fleqn}
;;\\fi")


(provide 'init)
;;; init.el ends here
