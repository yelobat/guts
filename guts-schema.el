;;; guts-schema.el --- Registry schema helpers for guts -*- lexical-binding: t; -*-
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
;; Helpers built on top of the BRP registry schema: listing insertable
;; components and resources, and scaffolding default JSON values for
;; arbitrary registered types so they can be inserted from the editor.
;;
;;; Code:

(require 'json)
(require 'brpel)

(defconst guts-schema--max-depth 8
  "Maximum recursion depth when scaffolding default values.")

(defun guts-schema--result ()
  "Return the registry schema result, populating the cache if needed."
  (unless brpel--registry-schema-cache
    (brpel--registry-schema-index-populate))
  (alist-get 'result brpel--registry-schema-cache))

(defun guts-schema-refresh ()
  "Re-fetch the registry schema from the BRP server."
  (interactive)
  (brpel--registry-schema-index-populate))

(defun guts-schema--entry (type-path)
  "Return the raw schema entry for TYPE-PATH, or nil if unregistered."
  (alist-get (intern type-path) (guts-schema--result)))

(defun guts-schema--reflects-p (entry reflect)
  "Whether schema ENTRY lists REFLECT among its reflect types."
  (seq-contains-p (alist-get 'reflectTypes entry) reflect))

(defun guts-schema-type-paths (reflect)
  "Return all registered type paths whose reflect types include REFLECT.
REFLECT is a string such as \"Component\" or \"Resource\"."
  (let (paths)
    (dolist (cell (guts-schema--result))
      (when (guts-schema--reflects-p (cdr cell) reflect)
        (push (symbol-name (car cell)) paths)))
    (sort paths #'string<)))

(defun guts-schema-short-path (type-path)
  "Return the short path for TYPE-PATH, falling back to TYPE-PATH."
  (or (alist-get 'shortPath (guts-schema--entry type-path)) type-path))

(defun guts-schema--ref-type-path (field)
  "Extract the type path referenced by schema FIELD."
  (when-let ((ref (alist-get '$ref (alist-get 'type field))))
    (car (last (split-string ref "/")))))

(defun guts-schema--field-default (field depth)
  "Return default JSON text for schema FIELD at recursion DEPTH."
  (let ((type-path (guts-schema--ref-type-path field)))
    (if type-path
        (guts-schema--default (guts-schema--entry type-path) (1+ depth))
      "null")))

(defconst guts-schema--glam-defaults
  '(("Vec2" . "[0.0, 0.0]") ("DVec2" . "[0.0, 0.0]")
    ("Vec3" . "[0.0, 0.0, 0.0]") ("Vec3A" . "[0.0, 0.0, 0.0]")
    ("DVec3" . "[0.0, 0.0, 0.0]")
    ("Vec4" . "[0.0, 0.0, 0.0, 0.0]") ("DVec4" . "[0.0, 0.0, 0.0, 0.0]")
    ("UVec2" . "[0, 0]") ("UVec3" . "[0, 0, 0]") ("UVec4" . "[0, 0, 0, 0]")
    ("IVec2" . "[0, 0]") ("IVec3" . "[0, 0, 0]") ("IVec4" . "[0, 0, 0, 0]")
    ("Quat" . "[0.0, 0.0, 0.0, 1.0]"))
  "JSON defaults for glam math types, which serialize as arrays.")

(defun guts-schema-default-json (type-path)
  "Return default JSON text for the type named by TYPE-PATH."
  (guts-schema--default (guts-schema--entry type-path) 0))

(defun guts-schema--default (entry depth)
  "Return default JSON text for schema ENTRY at recursion DEPTH."
  (if (or (null entry) (> depth guts-schema--max-depth))
      "null"
    (let* ((kind (alist-get 'kind entry))
           (type-path (alist-get 'typePath entry))
           (short (alist-get 'shortPath entry))
           (glam (cdr (assoc short guts-schema--glam-defaults))))
      (cond
       ((and type-path (string-prefix-p "core::option::Option" type-path))
        "null")
       ;; The schema cannot express Rust Default values, so a scaffolded
       ;; Transform would get a zero scale.  Use the identity instead.
       ((equal type-path "bevy_transform::components::transform::Transform")
        (concat "{\"translation\": [0.0, 0.0, 0.0],"
                " \"rotation\": [0.0, 0.0, 0.0, 1.0],"
                " \"scale\": [1.0, 1.0, 1.0]}"))
       (glam glam)
       ((equal kind "Value") (guts-schema--default-value entry))
       ((equal kind "Struct") (guts-schema--default-struct entry depth))
       ((member kind '("TupleStruct" "Tuple"))
        (guts-schema--default-tuple entry depth))
       ((equal kind "Enum") (guts-schema--default-enum entry depth))
       ((member kind '("List" "Array" "Set")) "[]")
       ((equal kind "Map") "{}")
       (t "null")))))

(defun guts-schema--default-value (entry)
  "Return default JSON text for a Value-kind schema ENTRY."
  (let ((type (alist-get 'type entry))
        (type-path (alist-get 'typePath entry)))
    (cond
     ((equal type "string") "\"\"")
     ((equal type "boolean") "false")
     ((equal type "number")
      (if (member type-path '("f32" "f64")) "0.0" "0"))
     (t "null"))))

(defun guts-schema--default-struct (entry depth)
  "Return default JSON text for a Struct-kind schema ENTRY at DEPTH."
  (let ((properties (alist-get 'properties entry)))
    (if (null properties)
        "{}"
      (concat "{"
              (mapconcat (lambda (prop)
                           (format "%s: %s"
                                   (json-encode (symbol-name (car prop)))
                                   (guts-schema--field-default (cdr prop) depth)))
                         properties ", ")
              "}"))))

(defun guts-schema--default-tuple (entry depth)
  "Return default JSON text for a Tuple(Struct)-kind schema ENTRY at DEPTH.
Single-element tuples are unwrapped, matching serde's newtype handling."
  (let ((items (append (alist-get 'prefixItems entry) nil)))
    (cond
     ((null items) "[]")
     ((= 1 (length items)) (guts-schema--field-default (car items) depth))
     (t (concat "["
                (mapconcat (lambda (item)
                             (guts-schema--field-default item depth))
                           items ", ")
                "]")))))

(defun guts-schema--default-enum (entry depth)
  "Return default JSON text for an Enum-kind schema ENTRY at DEPTH.
Uses the first variant: unit variants become a plain string, struct and
tuple variants become an externally tagged object."
  (let ((one-of (append (alist-get 'oneOf entry) nil)))
    (cond
     ((null one-of) "null")
     ((stringp (car one-of)) (json-encode (car one-of)))
     (t (let* ((variant (car one-of))
               (short (alist-get 'shortPath variant)))
          (if (or (alist-get 'properties variant)
                  (alist-get 'prefixItems variant))
              (format "{%s: %s}" (json-encode short)
                      (guts-schema--default variant (1+ depth)))
            (json-encode short)))))))

(provide 'guts-schema)
;;; guts-schema.el ends here
