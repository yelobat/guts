;;; guts-transform.el --- Interactive Transform manipulation for guts -*- lexical-binding: t; -*-
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
;; A persistent transient menu for moving, rotating, and scaling an
;; entity live over BRP.  The menu stays open between keypresses, so an
;; entity can be nudged around the scene by tapping keys, similar to
;; how blender's gizmos or magit's persistent transients feel.
;;
;;; Code:

(require 'transient)
(require 'brpel)
(require 'guts-common)

(defvar guts-transform--entity nil
  "The entity currently targeted by the transform menu.")

(defvar guts-transform--step 0.5
  "Distance moved per translation nudge.")

(defvar guts-transform--angle 15.0
  "Degrees rotated per rotation nudge.")

(defvar guts-transform--scale-factor 1.1
  "Factor applied per scale nudge.")

(defun guts-transform--type-path ()
  "Return the full type path of bevy's Transform component."
  (or (brpel-type-path "Transform")
      "bevy_transform::components::transform::Transform"))

(defun guts-transform--deg->rad (degrees)
  "Convert DEGREES to radians."
  (* degrees (/ float-pi 180.0)))

(defun guts-transform--get ()
  "Fetch the Transform of the target entity, or nil if it has none."
  (let* ((type-path (guts-transform--type-path))
         (response (brpel-world-get-components-synchronously
                    guts-transform--entity (vector type-path)))
         (result (alist-get 'result response)))
    (alist-get (intern type-path) (alist-get 'components result))))

(defun guts-transform--ensure ()
  "Ensure the target entity has a Transform, offering to insert one."
  (unless (guts-transform--get)
    (if (y-or-n-p (format "Entity %s has no Transform.  Insert identity? "
                          guts-transform--entity))
        (guts--brp-check
         (brpel-world-insert-components-synchronously
          guts-transform--entity
          `((,(intern (guts-transform--type-path))
             . ((translation . [0.0 0.0 0.0])
                (rotation . [0.0 0.0 0.0 1.0])
                (scale . [1.0 1.0 1.0]))))))
      (user-error "Entity %s has no Transform" guts-transform--entity))))

(defun guts-transform--mutate (path value)
  "Mutate PATH of the target entity's Transform to VALUE."
  (guts--brp-check
   (brpel-world-mutate-components-synchronously
    guts-transform--entity (guts-transform--type-path) path value)))

(defun guts-transform--floats (sequence)
  "Return SEQUENCE as a vector of floats."
  (vconcat (mapcar #'float sequence)))

(defun guts-transform--nudge (index sign)
  "Nudge the translation axis at INDEX by SIGN times the current step."
  (let* ((translation (copy-sequence
                       (alist-get 'translation (guts-transform--get)))))
    (aset translation index
          (+ (aref translation index) (* sign guts-transform--step)))
    (setq translation (guts-transform--floats translation))
    (guts-transform--mutate "translation" translation)
    (message "Translation: %s" (json-encode translation))))

(defun guts-transform--axis-quat (axis radians)
  "Return the quaternion rotating RADIANS around AXIS (0, 1, or 2)."
  (let ((s (sin (/ radians 2.0)))
        (c (cos (/ radians 2.0))))
    (pcase axis
      (0 (vector s 0.0 0.0 c))
      (1 (vector 0.0 s 0.0 c))
      (2 (vector 0.0 0.0 s c)))))

(defun guts-transform--quat-mul (a b)
  "Return the quaternion product A * B, both in [x y z w] order."
  (let ((ax (float (aref a 0))) (ay (float (aref a 1)))
        (az (float (aref a 2))) (aw (float (aref a 3)))
        (bx (float (aref b 0))) (by (float (aref b 1)))
        (bz (float (aref b 2))) (bw (float (aref b 3))))
    (vector
     (- (+ (* aw bx) (* ax bw) (* ay bz)) (* az by))
     (+ (- (* aw by) (* ax bz)) (* ay bw) (* az bx))
     (- (+ (* aw bz) (* ax by) (* az bw)) (* ay bx))
     (- (* aw bw) (* ax bx) (* ay by) (* az bz)))))

(defun guts-transform--rotate (axis sign)
  "Rotate the entity around AXIS by SIGN times the current angle."
  (let* ((rotation (alist-get 'rotation (guts-transform--get)))
         (delta (guts-transform--axis-quat
                 axis (* sign (guts-transform--deg->rad
                               guts-transform--angle))))
         (new (guts-transform--quat-mul delta rotation)))
    (guts-transform--mutate "rotation" new)
    (message "Rotation: %s" (json-encode new))))

(defun guts-transform--rescale (factor)
  "Multiply the entity's scale uniformly by FACTOR."
  (let* ((scale (alist-get 'scale (guts-transform--get)))
         (new (vconcat (mapcar (lambda (v) (* (float v) factor)) scale))))
    (guts-transform--mutate "scale" new)
    (message "Scale: %s" (json-encode new))))

(defun guts-transform--read-vec3 (label)
  "Read three numbers labelled with LABEL, returning a float vector."
  (vector (float (read-number (format "%s X: " label)))
          (float (read-number (format "%s Y: " label)))
          (float (read-number (format "%s Z: " label)))))

;; Nudge commands

(defun guts-transform-x-inc ()
  "Nudge the entity along +X."
  (interactive)
  (guts-transform--nudge 0 1))

(defun guts-transform-x-dec ()
  "Nudge the entity along -X."
  (interactive)
  (guts-transform--nudge 0 -1))

(defun guts-transform-y-inc ()
  "Nudge the entity along +Y."
  (interactive)
  (guts-transform--nudge 1 1))

(defun guts-transform-y-dec ()
  "Nudge the entity along -Y."
  (interactive)
  (guts-transform--nudge 1 -1))

(defun guts-transform-z-inc ()
  "Nudge the entity along +Z."
  (interactive)
  (guts-transform--nudge 2 1))

(defun guts-transform-z-dec ()
  "Nudge the entity along -Z."
  (interactive)
  (guts-transform--nudge 2 -1))

(defun guts-transform-rotate-x-inc ()
  "Rotate the entity around +X."
  (interactive)
  (guts-transform--rotate 0 1))

(defun guts-transform-rotate-x-dec ()
  "Rotate the entity around -X."
  (interactive)
  (guts-transform--rotate 0 -1))

(defun guts-transform-rotate-y-inc ()
  "Rotate the entity around +Y."
  (interactive)
  (guts-transform--rotate 1 1))

(defun guts-transform-rotate-y-dec ()
  "Rotate the entity around -Y."
  (interactive)
  (guts-transform--rotate 1 -1))

(defun guts-transform-rotate-z-inc ()
  "Rotate the entity around +Z."
  (interactive)
  (guts-transform--rotate 2 1))

(defun guts-transform-rotate-z-dec ()
  "Rotate the entity around -Z."
  (interactive)
  (guts-transform--rotate 2 -1))

(defun guts-transform-scale-up ()
  "Scale the entity up by the scale factor."
  (interactive)
  (guts-transform--rescale guts-transform--scale-factor))

(defun guts-transform-scale-down ()
  "Scale the entity down by the scale factor."
  (interactive)
  (guts-transform--rescale (/ 1.0 guts-transform--scale-factor)))

;; Absolute set commands

(defun guts-transform-set-translation ()
  "Set the entity's translation to an absolute value."
  (interactive)
  (let ((translation (guts-transform--read-vec3 "Translation")))
    (guts-transform--mutate "translation" translation)
    (message "Translation: %s" (json-encode translation))))

(defun guts-transform-set-rotation ()
  "Set the entity's rotation from Euler angles in degrees (XYZ order)."
  (interactive)
  (let* ((rx (guts-transform--deg->rad (read-number "Rotate X (deg): " 0)))
         (ry (guts-transform--deg->rad (read-number "Rotate Y (deg): " 0)))
         (rz (guts-transform--deg->rad (read-number "Rotate Z (deg): " 0)))
         (rotation (guts-transform--quat-mul
                    (guts-transform--axis-quat 2 rz)
                    (guts-transform--quat-mul
                     (guts-transform--axis-quat 1 ry)
                     (guts-transform--axis-quat 0 rx)))))
    (guts-transform--mutate "rotation" rotation)
    (message "Rotation: %s" (json-encode rotation))))

(defun guts-transform-set-scale ()
  "Set the entity's scale to an absolute value."
  (interactive)
  (let ((scale (guts-transform--read-vec3 "Scale")))
    (guts-transform--mutate "scale" scale)
    (message "Scale: %s" (json-encode scale))))

;; Option commands

(defun guts-transform-set-step ()
  "Set the translation step size."
  (interactive)
  (setq guts-transform--step
        (float (read-number "Step: " guts-transform--step))))

(defun guts-transform-set-angle ()
  "Set the rotation angle in degrees."
  (interactive)
  (setq guts-transform--angle
        (float (read-number "Angle (deg): " guts-transform--angle))))

(defun guts-transform-set-scale-factor ()
  "Set the scale nudge factor."
  (interactive)
  (setq guts-transform--scale-factor
        (float (read-number "Scale factor: " guts-transform--scale-factor))))

(defun guts-transform--menu-description ()
  "Describe the transform menu target and current settings."
  (let ((transform (guts-transform--get)))
    (format "Transform entity %s  (step %.3g, angle %.3g°, factor %.3g)\n%s"
            guts-transform--entity
            guts-transform--step
            guts-transform--angle
            guts-transform--scale-factor
            (if transform (json-encode transform) "no Transform"))))

(transient-define-prefix guts-transform-menu ()
  "Translate, rotate, and scale an entity via BRP mutations.
The menu stays open, so the entity can be nudged repeatedly."
  [:description guts-transform--menu-description
   ["Translate"
    ("x" "+X" guts-transform-x-inc :transient t)
    ("X" "-X" guts-transform-x-dec :transient t)
    ("y" "+Y" guts-transform-y-inc :transient t)
    ("Y" "-Y" guts-transform-y-dec :transient t)
    ("z" "+Z" guts-transform-z-inc :transient t)
    ("Z" "-Z" guts-transform-z-dec :transient t)]
   ["Rotate"
    ("u" "+around X" guts-transform-rotate-x-inc :transient t)
    ("U" "-around X" guts-transform-rotate-x-dec :transient t)
    ("i" "+around Y" guts-transform-rotate-y-inc :transient t)
    ("I" "-around Y" guts-transform-rotate-y-dec :transient t)
    ("o" "+around Z" guts-transform-rotate-z-inc :transient t)
    ("O" "-around Z" guts-transform-rotate-z-dec :transient t)]
   ["Scale"
    (">" "Grow" guts-transform-scale-up :transient t)
    ("<" "Shrink" guts-transform-scale-down :transient t)]
   ["Set"
    ("t" "Translation..." guts-transform-set-translation :transient t)
    ("r" "Rotation (Euler°)..." guts-transform-set-rotation :transient t)
    ("c" "Scale..." guts-transform-set-scale :transient t)]
   ["Options"
    ("s" "Step..." guts-transform-set-step :transient t)
    ("a" "Angle..." guts-transform-set-angle :transient t)
    ("f" "Scale factor..." guts-transform-set-scale-factor :transient t)
    ("q" "Quit" transient-quit-one)]])

(defun guts-transform (entity)
  "Open the interactive transform menu for ENTITY."
  (interactive (list (read-number "Entity ID: ")))
  (setq guts-transform--entity entity)
  (guts-transform--ensure)
  (call-interactively #'guts-transform-menu))

(provide 'guts-transform)
;;; guts-transform.el ends here
