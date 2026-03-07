;;; guts-components.el --- Components functionality for guts -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: March 01, 2026
;; Modified: March 01, 2026
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex text tools unix vc wp
;; Homepage: https://github.com/yelobat/guts
;; Package-Requires: ((emacs "28.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;
;;
;;; Code:

(defvar guts-components--current-component nil
  "The current component that is being viewed.")

(defun guts-components--set-current-component (component)
  "Set the current component to COMPONENT."
  (setq guts-components--current-component component))

(defun guts-components--refresh ()
  "Refresh the currently selected component."
  (setq guts-components--current-component nil))

(provide 'guts-components)
;;; guts-components.el ends here
