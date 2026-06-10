;;; guts-resources.el --- Resources functionality for guts -*- lexical-binding: t; -*-
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

(require 'brpel)
(require 'guts-common)

(defvar guts-resources--current-resource nil
  "The current resource that is being viewed.")

(defun guts-resources--set-current-resource (resource)
  "Set the current resource to RESOURCE."
  (setq guts-resources--current-resource resource))

(defun guts-resources--refresh ()
  "Refresh the currently selected resource."
  (setq guts-resources--current-resource nil))

(defun guts-resources ()
  "Get all of the resources in the current app.
The returned format is (list RESOURCE-NAME)."
  (alist-get 'result (brpel-world-list-resources-synchronously)))

(provide 'guts-resources)
;;; guts-resources.el ends here
