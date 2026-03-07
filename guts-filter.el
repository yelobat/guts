;;; guts-filter.el --- Filter functionality and view for guts -*- lexical-binding: t; -*-
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
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;
;;
;;; Code:

(defvar guts-filter--exclude-components nil
  "The components which are being excluded in the ECS viewer.")

(defvar guts-filter--include-components nil
  "The components which are being included in the ECS viewer.")

(defun guts-filter--add-exclude-component (component)
  "Add COMPONENT to the exclude component filter."
  (when component
    (add-to-list 'guts-filter--exclude-components component t)))

(defun guts-filter--add-include-component (component)
  "Add COMPONENT to the include component filter."
  (when component
    (add-to-list 'guts-filter--include-components component t)))

(defun guts-filter--exclude-refresh ()
  "Refresh the exclude component filter."
  (setq guts-filter--exclude-components nil))

(defun guts-filter--include-refresh ()
  "Refresh the include component filter."
  (setq guts-filter--include-components nil))

(defun guts-filter--refresh ()
  "Refresh the guts component filters."
  (interactive)
  (guts-filter--exclude-refresh)
  (guts-filter--include-refresh))

(provide 'guts-filter)
;;; guts-filter.el ends here
