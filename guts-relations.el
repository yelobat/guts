;;; guts-relations.el --- Relationship functionality for guts -*- lexical-binding: t; -*-
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

(defvar guts-relations--marked-children nil
  "The current list of marked children.")

(defvar guts-relations--marked-parent nil
  "The currently marked parent.")

(defun guts-relations--set-parent (parent)
  "Set PARENT to be the marked parent for future operations."
  (setq guts-relations--marked-parent parent))

(defun guts-relations--add-child (child)
  "Add CHILD to the list of marked children for future operations."
  (add-to-list 'guts-relations--marked-children child))

(defun guts-relations--remove-parent ()
  "Remove the currently marked parent."
  (setq guts-relations--marked-parent nil))

(defun guts-relations--remove-child (child)
  "Remove the currently marked CHILD."
  (delete child guts-relations--marked-children))

(defun guts-relations--parent-p (entity)
  "Predicate as to whether ENTITY is the marked parent."
  (= entity guts-relations--marked-parent))

(defun guts-relations--child-p (entity)
  "Predicate as to whether ENTITY is a marked child."
  (seq-contains-p guts-relations--marked-children entity))

(defun guts-relations--refresh ()
  "Refresh the marked children and marked parent."
  (setq
   guts-relations--marked-children nil
   guts-relations--marked-parent nil))

(provide 'guts-relations)
;;; guts-relations.el ends here
