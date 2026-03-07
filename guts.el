;;; guts.el --- A bevy editor from within Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: February 28, 2026
;; Modified: February 28, 2026
;; Version: 0.0.1
;; Keywords: text tools
;; Homepage: https://github.com/yelobat/guts
;; Package-Requires: ((emacs "28.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; Guts is a bevy editor from within Emacs. It is
;; dependent on the brpel package and can't be used without
;; it.
;;
;;; Code:

(require 'brpel)
(require 'ron)

(require 'guts-common)
(require 'guts-ecs)

(defun guts--try-connection ()
  "Attempts to perform a connection to the BRP server."
  (condition-case _err
      (and (brpel-rpc-discover-synchronously) t)
    (error nil)))

(defun guts--update-connection ()
  "Update the connection to the BRP server."
  (let ((prompt "Connection failed. Enter BRP server location (CURRENT: %s): "))
    (brpel-url-set (read-string (format prompt brpel-request-url))))
  (message (format "BRP server now located at: '%s'" brpel-request-url)))

(defun guts ()
  "Start and open guts."
  (interactive)
  (unless (guts--try-connection)
    (guts--update-connection))
  (condition-case err
      (progn
        (brpel-rpc-discover-synchronously)
        (guts-ecs--entity-view))
    (error (message err))))

(provide 'guts)
;;; guts.el ends here
