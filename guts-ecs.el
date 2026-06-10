;;; guts-ecs.el --- tabulated-list ECS interface for guts -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2026 Luke Holland
;;
;; Author: Luke Holland
;; Maintainer: Luke Holland
;; Created: March 04, 2026
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
;; The interactive ECS browser: entity, component, and resource views,
;; mark/execute workflows, spawning, renaming, component insertion, and
;; the top-level `guts-dispatch' transient.
;;
;;; Code:

(require 'tabulated-list)
(require 'transient)
(require 'guts-common)
(require 'guts-filter)
(require 'guts-entities)
(require 'guts-resources)
(require 'guts-relations)
(require 'guts-edit)
(require 'guts-schema)
(require 'guts-transform)

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
  (setq guts-ecs--marked-delete-list
        (delete thing guts-ecs--marked-delete-list)))

(defun guts-ecs--marked-refresh ()
  "Refresh all markings."
  (setq guts-ecs--marked-delete-list nil)
  (guts-relations--refresh))

(defun guts-ecs--name-type-path ()
  "Return the full type path of bevy's Name component."
  (or (brpel-type-path "Name") "bevy_ecs::name::Name"))

;; Entity Mode

(defvar guts-ecs-entity-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'guts-ecs--entity-select)
    (define-key map (kbd "g") #'guts-ecs--entity-view)
    (define-key map (kbd "r") #'guts-ecs--resource-view)
    (define-key map (kbd "C") #'guts-ecs--entity-mark-child)
    (define-key map (kbd "P") #'guts-ecs--entity-mark-parent)
    (define-key map (kbd "d") #'guts-ecs--entity-mark-delete)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--entity-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--entity-execute)
    (define-key map (kbd "+") #'guts-ecs--entity-spawn)
    (define-key map (kbd "R") #'guts-ecs--entity-rename)
    (define-key map (kbd "t") #'guts-ecs--entity-transform)
    (define-key map (kbd "i") #'guts-ecs--entity-insert-component)
    (define-key map (kbd "f") #'guts-ecs--entity-filter-menu)
    (define-key map (kbd "m") #'guts-dispatch)
    (define-key map (kbd "?") #'guts-dispatch)
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

(defun guts-ecs--entity-at-point ()
  "Return the entity ID of the row at point."
  (let ((entry (tabulated-list-get-entry)))
    (unless entry
      (user-error "No entity at point"))
    (string-to-number (aref entry 1))))

(defun guts-ecs--entity-add-marked-delete ()
  "Add the current entity as a thing to be deleted."
  (add-to-list 'guts-ecs--marked-delete-list (guts-ecs--entity-at-point)))

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
    (guts-relations--set-parent (guts-ecs--entity-at-point))
    (guts-ecs--update-mark guts-ecs--parent-mark t)))

(defun guts-ecs--entity-mark-child ()
  "Update the entry with a Child marker."
  (interactive)
  (guts-relations--add-child (guts-ecs--entity-at-point))
  (guts-ecs--update-mark guts-ecs--child-mark t))

(defun guts-ecs--entity-unmark (&optional advance)
  "Remove the current marker for the given entry.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (let ((id (guts-ecs--entity-at-point)))
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
  (let ((line (when (derived-mode-p 'guts-ecs-entity-mode)
                (line-number-at-pos))))
    (guts-entities--refresh)
    (guts-resources--refresh)
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
        (tabulated-list-print)
        (when line
          (goto-char (point-min))
          (forward-line (1- line))))
      (switch-to-buffer buffer))))

(defun guts-ecs--entity-execute ()
  "Execute the markings for the marked entities."
  (interactive)
  (dolist (entity guts-ecs--marked-delete-list)
    (brpel-world-despawn-entity-synchronously entity))
  (when guts-relations--marked-children
    (brpel-world-reparent-entities-synchronously
     (vconcat guts-relations--marked-children)
     guts-relations--marked-parent))
  (guts-ecs--marked-refresh)
  (guts-ecs--entity-view))

(defun guts-ecs--entity-select ()
  "Select the current entity and view its components."
  (interactive)
  (guts-entities--set-current-entity (guts-ecs--entity-at-point))
  (guts-ecs--component-view))

(defun guts-ecs--set-name (entity name)
  "Insert a Name component with value NAME on ENTITY."
  (guts--brp-check
   (brpel-world-insert-components-synchronously
    entity `((,(intern (guts-ecs--name-type-path)) . ,name)))))

(defun guts-ecs--entity-spawn ()
  "Spawn a new entity, optionally with a Name component."
  (interactive)
  (let* ((name (read-string "Name (leave empty for unnamed): "))
         (components (if (string= "" name)
                         (make-hash-table)
                       `((,(intern (guts-ecs--name-type-path)) . ,name))))
         (result (guts--brp-check
                  (brpel-world-spawn-entity-synchronously components))))
    (guts-ecs--entity-view)
    (message "Spawned entity %s" (alist-get 'entity result))))

(defun guts-ecs--entity-rename ()
  "Set the Name component of the entity at point."
  (interactive)
  (let* ((entry (tabulated-list-get-entry))
         (id (guts-ecs--entity-at-point))
         (current (aref entry 2))
         (name (read-string "Name: " (unless (string= current "nil") current))))
    (guts-ecs--set-name id name)
    (guts-ecs--entity-view)
    (message "Renamed entity %s to %S" id name)))

(defun guts-ecs--entity-transform ()
  "Open the transform menu for the entity at point."
  (interactive)
  (guts-transform (guts-ecs--entity-at-point)))

(defun guts-ecs--insert-component (entity refresh-fn)
  "Prompt for a component type and insert it on ENTITY.
Simple components (such as Name) are read from the minibuffer, other
components open a `guts-edit' buffer scaffolded with default values.
REFRESH-FN is called after a successful insert."
  (let* ((type-path (completing-read "Insert component: "
                                     (guts-schema-type-paths "Component")
                                     nil t))
         (short (guts-schema-short-path type-path)))
    (if (string= type-path (guts-ecs--name-type-path))
        (progn
          (guts-ecs--set-name entity (read-string "Name: "))
          (funcall refresh-fn))
      (guts-edit-open
       (format "Insert %s on entity %s" short entity)
       (guts-schema-default-json type-path)
       (lambda (value)
         (guts--brp-check
          (brpel-world-insert-components-synchronously
           entity `((,(intern type-path) . ,value))))
         (message "Inserted %s on entity %s" short entity)
         (funcall refresh-fn))))))

(defun guts-ecs--entity-insert-component ()
  "Insert a component on the entity at point."
  (interactive)
  (guts-ecs--insert-component (guts-ecs--entity-at-point)
                              #'guts-ecs--entity-view))

;; Component Mode

(defvar guts-ecs-component-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'guts-ecs--component-select)
    (define-key map (kbd "g") #'guts-ecs--component-view)
    (define-key map (kbd "e") #'guts-ecs--entity-view)
    (define-key map (kbd "r") #'guts-ecs--resource-view)
    (define-key map (kbd "d") #'guts-ecs--component-mark-delete)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--component-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--component-execute)
    (define-key map (kbd "i") #'guts-ecs--component-insert)
    (define-key map (kbd "M") #'guts-ecs--component-mutate)
    (define-key map (kbd "t") #'guts-ecs--component-transform)
    (define-key map (kbd "m") #'guts-dispatch)
    (define-key map (kbd "?") #'guts-dispatch)
    map)
  "Keymap for guts-ecs-component Mode.")

(define-derived-mode guts-ecs-component-mode tabulated-list-mode "Guts Components"
  "Major mode for displaying an entity's components in the guts ECS."
  (setq tabulated-list-format [("Type" 10 t)
                               ("Name" 64 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun guts-ecs--component-at-point ()
  "Return the type path of the component row at point."
  (let ((entry (tabulated-list-get-entry)))
    (unless entry
      (user-error "No component at point"))
    (aref entry 1)))

(defun guts-ecs--component-select ()
  "Edit the value of the component at point."
  (interactive)
  (let* ((name (guts-ecs--component-at-point))
         (entity guts-entities--current-entity)
         (result (guts--brp-check
                  (brpel-world-get-components-synchronously
                   entity (vector name))))
         (value (alist-get (intern name) (alist-get 'components result))))
    (guts-edit-open
     (format "%s on entity %s" name entity)
     (json-encode value)
     (lambda (value)
       (guts--brp-check
        (brpel-world-insert-components-synchronously
         entity `((,(intern name) . ,value))))
       (message "Updated %s on entity %s" name entity)))))

(defun guts-ecs--component-add-marked-delete ()
  "Add the current component as a thing to be deleted."
  (add-to-list 'guts-ecs--marked-delete-list (guts-ecs--component-at-point)))

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
  (when (guts-ecs--delete-mark-p)
    (guts-ecs--remove-marked-delete (guts-ecs--component-at-point)))
  (guts-ecs--update-mark guts-ecs--empty-mark advance))

(defun guts-ecs--component-execute ()
  "Execute the markings for the marked components."
  (interactive)
  (when guts-ecs--marked-delete-list
    (guts--brp-check
     (brpel-world-remove-components-synchronously
      guts-entities--current-entity
      (vconcat guts-ecs--marked-delete-list))))
  (setq guts-ecs--marked-delete-list nil)
  (guts-ecs--component-view))

(defun guts-ecs--component-insert ()
  "Insert a component on the current entity."
  (interactive)
  (let ((entity guts-entities--current-entity))
    (guts-ecs--insert-component
     entity
     (lambda ()
       (guts-entities--set-current-entity entity)
       (guts-ecs--component-view)))))

(defun guts-ecs--component-mutate ()
  "Mutate a single field of the component at point."
  (interactive)
  (let* ((name (guts-ecs--component-at-point))
         (entity guts-entities--current-entity)
         (path (read-string "Field path (e.g. translation.x): "))
         (value (json-read-from-string (read-string "Value (JSON): "))))
    (guts--brp-check
     (brpel-world-mutate-components-synchronously entity name path value))
    (message "Mutated %s %s on entity %s" name path entity)))

(defun guts-ecs--component-transform ()
  "Open the transform menu for the current entity."
  (interactive)
  (guts-transform guts-entities--current-entity))

(defun guts-ecs--component-view ()
  "Component View ECS."
  (interactive)
  (unless guts-entities--current-entity
    (user-error "No entity selected"))
  (setq guts-ecs--marked-delete-list nil)
  (let ((buffer (get-buffer-create "*guts-ecs-components*")))
    (with-current-buffer buffer
      (guts-ecs-component-mode)
      (setq mode-name
            (format "Guts Components [%s]" guts-entities--current-entity))
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
    (define-key map (kbd "g") #'guts-ecs--resource-view)
    (define-key map (kbd "e") #'guts-ecs--entity-view)
    (define-key map (kbd "d") #'guts-ecs--resource-mark-delete)
    (define-key map (kbd "u") (lambda () (interactive) (guts-ecs--resource-unmark t)))
    (define-key map (kbd "x") #'guts-ecs--resource-execute)
    (define-key map (kbd "i") #'guts-ecs--resource-insert)
    (define-key map (kbd "m") #'guts-dispatch)
    (define-key map (kbd "?") #'guts-dispatch)
    map)
  "Keymap for guts-ecs-resource Mode.")

(define-derived-mode guts-ecs-resource-mode tabulated-list-mode "Guts Resources"
  "Major mode for displaying a resource in the guts ECS."
  (setq tabulated-list-format [("Type" 20 t)
                               ("Name" 64 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun guts-ecs--resource-at-point ()
  "Return the type path of the resource row at point."
  (let ((entry (tabulated-list-get-entry)))
    (unless entry
      (user-error "No resource at point"))
    (aref entry 1)))

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
  (when (guts-ecs--delete-mark-p)
    (guts-ecs--remove-marked-delete (guts-ecs--resource-at-point)))
  (guts-ecs--update-mark guts-ecs--empty-mark advance))

(defun guts-ecs--resource-select ()
  "Edit the value of the resource at point."
  (interactive)
  (let* ((name (guts-resources--set-current-resource
                (guts-ecs--resource-at-point)))
         (result (guts--brp-check
                  (brpel-world-get-resources-synchronously name)))
         (value (alist-get 'value result)))
    (guts-edit-open
     (format "Resource %s" name)
     (json-encode value)
     (lambda (value)
       (guts--brp-check
        (brpel-world-insert-resources-synchronously name value))
       (message "Updated resource %s" name)))))

(defun guts-ecs--resource-insert ()
  "Prompt for a resource type and insert it."
  (interactive)
  (let* ((name (completing-read "Insert resource: "
                                (guts-schema-type-paths "Resource")
                                nil t))
         (short (guts-schema-short-path name)))
    (guts-edit-open
     (format "Insert resource %s" short)
     (guts-schema-default-json name)
     (lambda (value)
       (guts--brp-check
        (brpel-world-insert-resources-synchronously name value))
       (message "Inserted resource %s" short)
       (guts-ecs--resource-view)))))

(defun guts-ecs--resource-add-marked-delete ()
  "Add the current resource as a thing to be deleted."
  (add-to-list 'guts-ecs--marked-delete-list (guts-ecs--resource-at-point)))

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
  (eql (guts-ecs--get-mark) guts-ecs--delete-mark))

(defun guts-ecs--child-mark-p ()
  "Check if the current mark is the child mark."
  (eql (guts-ecs--get-mark) guts-ecs--child-mark))

(defun guts-ecs--parent-mark-p ()
  "Check if the current mark is the parent mark."
  (eql (guts-ecs--get-mark) guts-ecs--parent-mark))

(defun guts-ecs--update-mark (char &optional advance)
  "Insert CHAR as the TAG for the current entry.
If ADVANCE is non-nil, advance to the next line."
  (interactive)
  (tabulated-list-put-tag (char-to-string char) advance))

;; Filters

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

;; Guts Dispatch Menu

(defun guts-ecs--entity-mode-p ()
  "Whether the current buffer is the entity view."
  (derived-mode-p 'guts-ecs-entity-mode))

(defun guts-ecs--component-mode-p ()
  "Whether the current buffer is the component view."
  (derived-mode-p 'guts-ecs-component-mode))

(defun guts-ecs--resource-mode-p ()
  "Whether the current buffer is the resource view."
  (derived-mode-p 'guts-ecs-resource-mode))

(transient-define-prefix guts-dispatch ()
  "Top-level guts menu."
  [["Views"
    ("e" "Entities" guts-ecs--entity-view)
    ("r" "Resources" guts-ecs--resource-view)]
   ["Entity at point" :if guts-ecs--entity-mode-p
    ("t" "Transform (move/rotate/scale)" guts-ecs--entity-transform)
    ("R" "Rename" guts-ecs--entity-rename)
    ("i" "Insert component..." guts-ecs--entity-insert-component)
    ("+" "Spawn new entity..." guts-ecs--entity-spawn)]
   ["Current entity" :if guts-ecs--component-mode-p
    ("t" "Transform (move/rotate/scale)" guts-ecs--component-transform)
    ("i" "Insert component..." guts-ecs--component-insert)
    ("M" "Mutate component field..." guts-ecs--component-mutate)]
   ["Resources" :if guts-ecs--resource-mode-p
    ("i" "Insert resource..." guts-ecs--resource-insert)]
   ["Marks"
    ("d" "Mark for deletion" guts-ecs--dispatch-mark-delete)
    ("u" "Unmark" guts-ecs--dispatch-unmark)
    ("x" "Execute marks" guts-ecs--dispatch-execute)]
   ["Filters"
    ("f" "Component filters" guts-ecs--entity-filter-menu)]])

(defun guts-ecs--dispatch-mark-delete ()
  "Mark the row at point for deletion, in any guts view."
  (interactive)
  (cond
   ((guts-ecs--entity-mode-p) (guts-ecs--entity-mark-delete))
   ((guts-ecs--component-mode-p) (guts-ecs--component-mark-delete))
   ((guts-ecs--resource-mode-p) (guts-ecs--resource-mark-delete))))

(defun guts-ecs--dispatch-unmark ()
  "Unmark the row at point, in any guts view."
  (interactive)
  (cond
   ((guts-ecs--entity-mode-p) (guts-ecs--entity-unmark t))
   ((guts-ecs--component-mode-p) (guts-ecs--component-unmark t))
   ((guts-ecs--resource-mode-p) (guts-ecs--resource-unmark t))))

(defun guts-ecs--dispatch-execute ()
  "Execute the pending marks, in any guts view."
  (interactive)
  (cond
   ((guts-ecs--entity-mode-p) (guts-ecs--entity-execute))
   ((guts-ecs--component-mode-p) (guts-ecs--component-execute))
   ((guts-ecs--resource-mode-p) (guts-ecs--resource-execute))))

(provide 'guts-ecs)
;;; guts-ecs.el ends here
