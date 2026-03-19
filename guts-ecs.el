;;; guts-ecs.el --- tabulated-list ECS interface for guts -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: March 04, 2026
;; Modified: March 04, 2026
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

(require 'tabulated-list)
(require 'transient)
(require 'guts-entities)
(require 'guts-resources)
(require 'guts-relations)

(defconst guts-ecs--parent-mark ?P
  "The marker corresponding to the marked parent.")

(defconst guts-ecs--child-mark ?C
  "The marker corresponding to a marked child.")

(defconst guts-ecs--delete-mark ?D
  "The marker corresponding to a marked item for deletion.")

(defconst guts-ecs--empty-mark ?\s
  "The empty marker.")

(defvar guts-ecs--marked-delete-list nil
  "The current list of things marked for deletion.")

(defun guts-ecs--remove-marked-delete (thing)
  "Remove THING from the list of things marked for deletion."
  (delete thing guts-ecs--marked-delete-list))

(defun guts-ecs--marked-refresh ()
  "Refresh all markings."
  (setq guts-ecs--marked-delete-list nil)
  (guts-relations--refresh))

;; TODO Write mode specific functions
;; Entity Mode

(defvar guts-ecs-entity-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C") #'guts-ecs--entity-mark-child)
    (define-key map (kbd "P") #'guts-ecs--entity-mark-parent)
    (define-key map (kbd "r") #'guts-ecs--resource-view)
    (define-key map (kbd "RET") #'guts-ecs--entity-select)
    (define-key map (kbd "g") #'guts-ecs--entity-view)
    (define-key map (kbd "m") #'guts-ecs--menu)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--entity-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--entity-execute)
    (define-key map (kbd "d") #'guts-ecs--entity-mark-delete)
    map)
  "Keymap for guts-ecs-entity Mode.")

(define-derived-mode guts-ecs-entity-mode tabulated-list-mode "Guts Entities"
  "Major mode for displaying entities in the guts display."
  (setq tabulated-list-format [("Type" 10 t)
                               ("ID" 12 t)
                               ("Name" 24 t)
                               ("ChildOf" 12 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun guts-ecs--entity-add-marked-delete ()
  "Add the current entity as a thing to be deleted."
  (let ((id (string-to-number (aref (tabulated-list-get-entry) 1))))
    (add-to-list 'guts-ecs--marked-delete-list id)))

(defun guts-ecs--entity-mark-delete ()
  "Update the entry with a Delete marker."
  (interactive)
  (guts-ecs--entity-unmark)
  (guts-ecs--entity-add-marked-delete)
  (guts-ecs--update-mark guts-ecs--delete-mark t))

(defun guts-ecs--entity-mark-parent ()
  "Update the entry with a Parent marker."
  (interactive)
  (when (string= "Entity" (aref (tabulated-list-get-entry) 0))
    (when guts-relations--marked-parent
      (save-excursion
        (goto-char (point-min))
        (while (and (not (eobp)) (/= guts-ecs--parent-mark (guts-ecs--get-mark)))
          (forward-line))
        (when (not (eobp))
          (guts-ecs--entity-unmark))))
    (guts-relations--set-parent (string-to-number (aref (tabulated-list-get-entry) 1)))
    (guts-ecs--update-mark guts-ecs--parent-mark t)))

(defun guts-ecs--entity-mark-child ()
  "Update the entry with a Child marker."
  (interactive)
  (let ((id (string-to-number (aref (tabulated-list-get-entry) 1))))
    (guts-relations--add-child id))
  (guts-ecs--update-mark guts-ecs--child-mark t))

(defun guts-ecs--entity-unmark (&optional advance)
  "Remove the current marker for the given entry.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (let ((id (string-to-number (aref (tabulated-list-get-entry) 1))))
    (cond
     ((guts-ecs--delete-mark-p)
      (guts-ecs--remove-marked-delete id))
     ((guts-ecs--child-mark-p)
      (guts-relations--remove-child id))
     ((guts-ecs--parent-mark-p)
      (guts-relations--remove-parent))))
  (guts-ecs--update-mark guts-ecs--empty-mark advance))

(defun guts-ecs--entity-view ()
  "Present the tabulated view of the guts ECS."
  (interactive)
  (guts-entities--refresh)
  (guts-resources--refresh)
  (guts-relations--refresh)
  (guts-ecs--marked-refresh)
  (let ((buffer (get-buffer-create "*guts-ecs-entities*")))
    (with-current-buffer buffer
      (guts-ecs-entity-mode)
      (setq tabulated-list-entries
            (let ((id 1))
              (mapcar
               (lambda (entry)
                 (prog1 (list id (vector
                                  "Entity"
                                  (number-to-string (elt entry 0))
                                  (or (elt entry 1) "nil")
                                  (if (elt entry 2)
                                      (number-to-string (elt entry 2))
                                    "nil")))
                   (setq id (1+ id))))
               (guts-entities))))
      (tabulated-list-print))
    (switch-to-buffer buffer)))

(defun guts-ecs--entity-execute ()
  "Execute the markings for the marked entities."
  (interactive)
  (dolist (entity guts-ecs--marked-delete-list)
    (brpel-world-despawn-entity-synchronously entity))
  (brpel-world-reparent-entities-synchronously
   (vconcat guts-relations--marked-children)
   guts-relations--marked-parent)
  (guts-ecs--marked-refresh)
  (guts-ecs--entity-view))

(defun guts-ecs--entity-select ()
  "Select the current entity and view it's components."
  (interactive)
  (let ((id (aref (tabulated-list-get-entry) 1)))
    (guts-entities--set-current-entity (string-to-number id))
    (guts-ecs--component-view)))

;; Component Mode

(defvar guts-ecs-component-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'guts-ecs--component-select)
    (define-key map (kbd "e") #'guts-ecs--entity-view)
    (define-key map (kbd "r") #'guts-ecs--resource-view)
    (define-key map (kbd "m") #'guts-ecs--menu)
    (define-key map (kbd "d") #'guts-ecs--component-mark-delete)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--component-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--component-execute)
    (define-key map (kbd "g") #'guts-ecs--component-view)
    map)
  "Keymap for guts-ecs-component Mode.")

(define-derived-mode guts-ecs-component-mode tabulated-list-mode "Guts Components"
  "Major mode for displaying an entitie's components in the guts ECS."
  (setq tabulated-list-format [("Type" 10 t)
                               ("Name" 64 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun guts-ecs--component-select ()
  "Select the current component for editing."
  (interactive)
  (let* ((name (aref (tabulated-list-get-entry) 1))
         (buffer (find-file-noselect guts-common--editor-file))
         (result (alist-get 'result (brpel-world-get-components-synchronously
                  guts-entities--current-entity
                  (vector name))))
         (component (alist-get 'components result)))
    (with-current-buffer buffer
      (erase-buffer)
      (guts-edit-mode)
      (save-excursion
        (insert (json-encode component)))
      (json-pretty-print-buffer)
      (switch-to-buffer-other-window (current-buffer)))))

(defun guts-ecs--component-add-marked-delete ()
  "Add the current component as athing to be deleted."
  (let ((name (aref (tabulated-list-get-entry) 1)))
    (add-to-list 'guts-ecs--marked-delete-list name)))

(defun guts-ecs--component-mark-delete ()
  "Update the component with a Delete marker."
  (interactive)
  (guts-ecs--component-unmark)
  (guts-ecs--component-add-marked-delete)
  (guts-ecs--update-mark guts-ecs--delete-mark t))

(defun guts-ecs--component-unmark (&optional advance)
  "Remove the current marker for the given component.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (let ((name (aref (tabulated-list-get-entry) 1)))
    (cond
     ((guts-ecs--delete-mark-p)
      (guts-ecs--remove-marked-delete name))))
  (guts-ecs--update-mark guts-ecs--empty-mark advance))

(defun guts-ecs--component-execute ()
  "Execute the markings for the marked components."
  (interactive)
  (brpel-world-remove-components-synchronously
   guts-entities--current-entity
   (vconcat guts-ecs--marked-delete-list))
  (guts-ecs--marked-refresh)
  (guts-ecs--component-view))

(defun guts-ecs--component-view ()
  "Component View ECS."
  (interactive)
  (let ((buffer (get-buffer-create "*guts-ecs-components*")))
    (with-current-buffer buffer
      (guts-ecs-component-mode)
      (setq tabulated-list-entries
            (let ((id 1))
              (mapcar (lambda (entry)
                        (prog1 (list id (vector
                                         "Component"
                                         entry))
                          (setq id (1+ id))))
                      (alist-get
                       'result
                       (brpel-world-list-components-synchronously
                        guts-entities--current-entity)))))
      (tabulated-list-print))
    (switch-to-buffer buffer)))

;; Resource Mode

(defvar guts-ecs-resource-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'guts-ecs--resource-select)
    (define-key map (kbd "e") #'guts-ecs--entity-view)
    (define-key map (kbd "m") #'guts-ecs--menu)
    (define-key map (kbd "d") #'guts-ecs--resource-mark-delete)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--resource-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--resource-execute)
    (define-key map (kbd "g") #'guts-ecs--resource-view)
    map)
  "Keymap for guts-ecs-resource Mode.")

(define-derived-mode guts-ecs-resource-mode tabulated-list-mode "Guts Resources"
  "Major mode for displaying a resource in the guts ECS."
  (setq tabulated-list-format [("Type" 20 t)
                               ("Name" 64 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun guts-ecs--resource-execute ()
  "Execute the markings for the marked resources."
  (interactive)
  (dolist (resource guts-ecs--marked-delete-list)
    (brpel-world-remove-resources-synchronously resource))
  (guts-ecs--marked-refresh)
  (guts-ecs--resource-view))

(defun guts-ecs--resource-unmark (&optional advance)
  "Remove the current marker for the given resource.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (let ((name (aref (tabulated-list-get-entry) 1)))
    (cond
     ((guts-ecs--delete-mark-p)
      (guts-ecs--remove-marked-delete name))))
  (guts-ecs--update-mark guts-ecs--empty-mark advance))

(defun guts-ecs--resource-select ()
  "Select the current resource for editing."
  (interactive)
  (let* ((name (guts-resources--set-current-resource (aref (tabulated-list-get-entry) 1)))
         (buffer (find-file-noselect guts-common--editor-file))
         (result (alist-get 'result (brpel-world-get-resources-synchronously
                  guts-resources--current-resource)))
         (value (alist-get 'value result)))
    (with-current-buffer buffer
      (erase-buffer)
      (guts-edit-mode)
      (save-excursion
        (insert (json-encode value)))
      (json-pretty-print (point) (point-max))
      (switch-to-buffer-other-window (current-buffer)))))

(defun guts-ecs--resource-add-marked-delete ()
  "Add the current resource as a thing to be deleted."
  (let ((name (aref (tabulated-list-get-entry) 1)))
    (add-to-list 'guts-ecs--marked-delete-list name)))

(defun guts-ecs--resource-mark-delete ()
  "Update the resource with a Delete marker."
  (interactive)
  (guts-ecs--resource-unmark)
  (guts-ecs--resource-add-marked-delete)
  (guts-ecs--update-mark guts-ecs--delete-mark t))

(defun guts-ecs--resource-view ()
  "Present the tabulated view of the resources in guts."
  (interactive)
  (guts-entities--refresh)
  (guts-resources--refresh)
  (guts-relations--refresh)
  (guts-ecs--marked-refresh)
  (let ((buffer (get-buffer-create "*guts-ecs-resources*")))
    (with-current-buffer buffer
      (guts-ecs-resource-mode)
      (setq tabulated-list-entries
            (let ((id 1))
              (mapcar
               (lambda (entry)
                 (prog1 (list id (vector
                                  "Resource"
                                  entry))
                   (setq id (1+ id))))
               (guts-resources))))
      (tabulated-list-print))
    (switch-to-buffer buffer)))

;; Utility functions

(defun guts-ecs--get-mark ()
  "Get the mark set for the current tabular listing."
  (let ((id (tabulated-list-get-id))
        (s (line-beginning-position)))
    (when id
      (string-to-char (buffer-substring-no-properties s (1+ s))))))

(defun guts-ecs--delete-mark-p ()
  "Check if the current mark is the delete mark."
  (= (guts-ecs--get-mark) guts-ecs--delete-mark))

(defun guts-ecs--child-mark-p ()
  "Check if the current mark is the child mark."
  (= (guts-ecs--get-mark) guts-ecs--child-mark))

(defun guts-ecs--parent-mark-p ()
  "Check if the current mark is the parent mark."
  (= (guts-ecs--get-mark) guts-ecs--parent-mark))

(defun guts-ecs--update-mark (char &optional advance)
  "Insert CHAR as the TAG for the current entry.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (tabulated-list-put-tag (char-to-string char) advance))

;; Save Hook functionality for editing
(add-hook 'after-save-hook #'guts-ecs--save-edits)

(defun guts-ecs--save-edits ()
  "Save the edits made to the component or resource to the ECS."
  (when guts-edit-mode
    (with-current-buffer (current-buffer)
      (let* ((contents (buffer-substring-no-properties (point-min) (point-max)))
             (result (json-read-from-string contents)))
        (cond
         ((or guts-entities--current-entity)
          (brpel-world-insert-components guts-entities--current-entity result))
         ((or guts-resources--current-resource)
          (brpel-world-insert-resources guts-resources--current-resource result)))))))

;; Guts Transient Menu

(defun guts-ecs--add-exclude-component ()
  "Accepts a component name to be used as part of an entity filter.
Adds this component name to the list of excluded components used to
filter entities."
  (interactive)
  (let* ((components (alist-get 'result (brpel-world-list-components-synchronously)))
         (collection (append components nil))
         (input (completing-read "Component: " collection)))
    (guts-filter--add-exclude-component input)
    (guts-ecs--entity-view)))

(defun guts-ecs--add-include-component ()
  "Accepts a component name to be used as part of an entity filter.
Adds this component name to the list of included components used to
filter entities."
  (interactive)
  (let* ((components (alist-get 'result (brpel-world-list-components-synchronously)))
         (collection (append components nil))
         (input (completing-read "Component: " collection)))
    (guts-filter--add-include-component input)
    (guts-ecs--entity-view)))

(defun guts-ecs--refresh-component-filters ()
  "Reset the excluded and included component filters."
  (interactive)
  (guts-filter--refresh)
  (guts-ecs--entity-view))

(transient-define-prefix guts-ecs--entity-filter-menu ()
  "Entity Component Filter Menu."
  ["Action"
   ("e" "Add exclusion filter..." guts-ecs--add-exclude-component)
   ("i" "Add inclusion filter..." guts-ecs--add-include-component)
   ("r" "Reset filters..." guts-ecs--refresh-component-filters)])

(transient-define-prefix guts-ecs--menu ()
  "ECS browser menu."
  ["Filters"
   ("c" "Filter Entities via Components" guts-ecs--entity-filter-menu)])

(provide 'guts-ecs)
;;; guts-ecs.el ends here
