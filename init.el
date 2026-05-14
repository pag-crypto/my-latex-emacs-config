;;; init.el --- LaTeX-focused Emacs config -*- lexical-binding: t; -*-

;;; Package setup
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
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
(set-face-attribute 'default nil :height 160)
(setq x-super-keysym 'meta)
(setq inhibit-startup-message t)
;;; autorevert to make it easier to edit taking turns with claude code
(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)        ; don't spam the minibuffer
(setq auto-revert-interval 1)         ; check every second

;; Silence the "PDF changed on disk, revert?" prompt — global-auto-revert
;; already reverts PDF buffers; this just stops the y/n confirmation.
(add-to-list 'revert-without-query "\\.pdf\\'")

;; PDFs must NOT poll-revert: pdf-tools races latexmk mid-write
;; ("PDF document is damaged"). AUCTeX's TeX-after-compilation-finished-functions
;; hook reverts the PDF cleanly once latexmk has fully exited.
(add-hook 'pdf-view-mode-hook (lambda () (auto-revert-mode -1)))

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

(use-package cdlatex)

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
  (pdf-tools-install :no-query))

;;; Continuous scroll for pdf-tools (via image-roll) — DISABLED.
;;;
;;; Kept as a reference in case a future image-roll release fixes the
;;; issues below. Symptoms observed when this was active:
;;;
;;;   1. (wrong-type-argument overlayp nil)
;;;      Fired from image-roll's pre-redisplay hook, often [N times] in
;;;      a burst. Cause: image-roll's overlay slots are not always
;;;      populated when pre-redisplay runs (e.g. just after a buffer
;;;      revert or window-config change), and it dereferences nil.
;;;
;;;   2. epdfinfo: Error opening <main.pdf>: PDF document is damaged
;;;      Fired from image-roll's pre-redisplay path during latexmk
;;;      recompilation. Cause: image-roll re-reads pages aggressively
;;;      on every redisplay; combined with global-auto-revert polling,
;;;      it caught main.pdf mid-write and poppler choked on the
;;;      truncated file.
;;;
;;; Mitigations attempted: (a) disabled auto-revert in pdf-view-mode
;;; buffers and rely on TeX-after-compilation-finished-functions
;;; (which still helps generally; that fix is kept above). Even with
;;; (a), image-roll's pre-redisplay still raced and produced (1).
;;; Removed the package outright as the cure.
;;;
;;; If re-enabling: check upstream activity at
;;; https://github.com/dalanicolai/image-roll.el first, and verify
;;; pre-redisplay no longer dereferences a nil overlay.
;;
;; (use-package image-roll
;;   :vc (:url "https://github.com/dalanicolai/image-roll.el")
;;   :after pdf-tools
;;   :hook (pdf-view-mode . pdf-view-roll-minor-mode))

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

;;; eat — pure-elisp terminal emulator. Used as the backend for
;;; claude-code-ide (vterm is faster but needs cmake + libvterm-dev to
;;; build its C module; eat works out of the box on any Emacs 28+).
(use-package eat)

;;; claude-code-ide — runs the Claude Code CLI inside Emacs and exposes
;;; Emacs's xref/imenu/project APIs to Claude over MCP. Not on MELPA;
;;; pulled directly from upstream via :vc. Requires the `claude' binary
;;; on PATH (set `claude-code-ide-cli-path' if it lives elsewhere).
;;; `C-c C-'' is global on purpose — useful from any buffer, not just LaTeX.
(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c C-'" . claude-code-ide-menu)
  :custom
  (claude-code-ide-terminal-backend 'eat)
  :config
  (claude-code-ide-emacs-tools-setup))

(use-package magit
	     :ensure t)

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
