;;; guts-edit.el --- Commit-style value editing for guts -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: June 09, 2026
;; Modified: June 09, 2026
;; Version: 0.0.1
;; Keywords: tools games
;; Homepage: https://github.com/yelobat/guts
;; Package-Requires: ((emacs "28.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; A magit-commit-style editing workflow for component and resource
;; values.  `guts-edit-open' pops up a JSON buffer; `C-c C-c' parses it
;; and hands the value to a commit function, `C-c C-k' aborts.  No
;; temporary files and no save hooks involved.
;;
;;; Code:

(require 'js)
(require 'json)

(defvar-local guts-edit--commit-fn nil
  "Function called with the parsed JSON value when committing.")

(defvar-local guts-edit--title nil
  "Human readable description of what is being edited.")

(define-derived-mode guts-edit-mode js-mode "Guts-Edit"
  "Major mode for editing a guts component or resource value as JSON.
Apply the edit with \\[guts-edit-commit], abort with \\[guts-edit-abort]."
  (setq-local require-final-newline nil))

(define-key guts-edit-mode-map (kbd "C-c C-c") #'guts-edit-commit)
(define-key guts-edit-mode-map (kbd "C-c C-k") #'guts-edit-abort)

(defun guts-edit-open (title initial commit-fn)
  "Pop up an edit buffer titled TITLE containing INITIAL JSON text.
COMMIT-FN is called with the parsed JSON value when the user commits
the buffer with \\[guts-edit-commit]."
  (let ((buffer (get-buffer-create "*guts-edit*")))
    (with-current-buffer buffer
      (erase-buffer)
      (guts-edit-mode)
      (insert (or initial "null"))
      (ignore-errors (json-pretty-print-buffer))
      (goto-char (point-min))
      (set-buffer-modified-p nil)
      (setq guts-edit--commit-fn commit-fn
            guts-edit--title title)
      (setq header-line-format
            (format "%s — C-c C-c: apply, C-c C-k: cancel" title)))
    (pop-to-buffer buffer)))

(defun guts-edit-commit ()
  "Parse the buffer as JSON and apply it via the commit function."
  (interactive)
  (unless guts-edit--commit-fn
    (user-error "Not a guts edit buffer"))
  (let ((value (json-read-from-string
                (buffer-substring-no-properties (point-min) (point-max))))
        (fn guts-edit--commit-fn)
        (buffer (current-buffer)))
    (funcall fn value)
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (set-buffer-modified-p nil))
      (let ((window (get-buffer-window buffer)))
        (if window
            (quit-window t window)
          (kill-buffer buffer))))))

(defun guts-edit-abort ()
  "Abort the current edit, discarding the buffer."
  (interactive)
  (set-buffer-modified-p nil)
  (quit-window t))

(provide 'guts-edit)
;;; guts-edit.el ends here
