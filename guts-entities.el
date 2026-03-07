;;; guts-entities.el --- Entity functionality for guts -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: March 02, 2026
;; Modified: March 02, 2026
;; Version: 0.0.1
;; Keywords: tools
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
(require 'guts-filter)

(defvar guts-entities--current-entity nil
  "The current entity that is being viewed.")

(defun guts-entities--set-current-entity (entity)
  "Set the current entity to ENTITY."
  (setq guts-entities--current-entity entity))

(defun guts-entities--refresh ()
  "Reset the current entity."
  (setq guts-entities--current-entity nil))

(defun guts-entities ()
  "Get all of the entities in the current app.
The returned format is (list ENTITY-ID NAME CHILD-OF)"
  (let* ((name-type-path (brpel-type-path "Name"))
         (child-of-type-path (brpel-type-path "ChildOf"))
         (response (brpel-world-query-synchronously
                    `((components . ,(vconcat guts-filter--include-components))
                      (option . ,(vector name-type-path child-of-type-path))
                      (has . []))
                    `((with . []) (without . ,(vconcat guts-filter--exclude-components)))))
         (result (append (alist-get 'result response) nil)))
    (mapcar (lambda (item) (let* ((entity (alist-get 'entity item))
                                  (components (alist-get 'components item))
                                  (name (alist-get (intern name-type-path) components))
                                  (child-of (alist-get (intern child-of-type-path) components)))
                             (list entity name child-of)))
            result)))

(provide 'guts-entities)
;;; guts-entities.el ends here
