;;; guts-common.el --- Common variables and functions for guts -*- lexical-binding: t; -*-
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

(defgroup guts nil
  "Guts - A bevy editor inside Emacs."
  :group 'tools)

(defun guts--brp-check (response)
  "Signal a `user-error' if RESPONSE contains a BRP error.
Otherwise return the result field of RESPONSE."
  (if-let ((err (alist-get 'error response)))
      (user-error "BRP error: %s" (alist-get 'message err))
    (alist-get 'result response)))

(provide 'guts-common)
;;; guts-common.el ends here
