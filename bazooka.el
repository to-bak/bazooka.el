;;; bazooka.el --- Explicit window-layout checkpoints -*- lexical-binding: t; -*-

;; Copyright (C) 2026 to-bak

;; Author: to-bak
;; Maintainer: to-bak
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, windows
;; URL: https://github.com/to-bak/bazooka.el
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Bazooka keeps a small, explicitly curated, per-frame list of window
;; layouts.  It is useful as a window-management safety net: remember a useful
;; layout, open a full-frame dashboard or rearrange some windows, then restore
;; the saved layout when it is useful again.
;;
;; Only `bazooka-remember' and `bazooka-toggle' add entries.  Ordinary buffer
;; and window changes do not affect the list.  Equivalent layouts are
;; refreshed instead of duplicated, and old entries are evicted when
;; `bazooka-capacity' is reached.
;;
;; `bazooka-consult' is an optional Consult integration with live whole-layout
;; previews.  The core package does not require Consult.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function consult--multi "consult" (sources &rest args))

(defgroup bazooka nil
  "Explicit window-layout checkpoints."
  :group 'windows)

(defcustom bazooka-capacity 4
  "Maximum number of window layouts remembered per frame."
  :type 'natnum
  :group 'bazooka)

(defcustom bazooka-preview-key 'any
  "Key used to preview Bazooka candidates in Consult.
The value has the same form as Consult's `:preview-key' setting."
  :type '(choice (const :tag "Any movement" any)
                 (const :tag "No preview" nil)
                 key-sequence)
  :group 'bazooka)

(cl-defstruct (bazooka-entry
               (:constructor bazooka--make-entry))
  "A saved Bazooka window layout."
  frame
  state
  signature)

(defconst bazooka--history-parameter 'bazooka-history
  "Frame parameter holding that frame's Bazooka entries.")

(defvar bazooka--consult-history nil
  "Minibuffer history for `bazooka-consult'.")

(defun bazooka--sorted-window-list (&optional frame)
  "Return FRAME's non-minibuffer windows sorted by their edges."
  (sort (window-list frame 'nomini)
        (lambda (left right)
          (let ((left-edges (window-edges left))
                (right-edges (window-edges right)))
            (catch 'ordered
              (while left-edges
                (cond
                 ((< (car left-edges) (car right-edges))
                  (throw 'ordered t))
                 ((> (car left-edges) (car right-edges))
                  (throw 'ordered nil)))
                (setq left-edges (cdr left-edges)
                      right-edges (cdr right-edges)))
              nil)))))

(defun bazooka--signature (&optional frame)
  "Return a material window-layout signature for FRAME.
Point, scrolling, and the selected window are deliberately excluded."
  (mapcar (lambda (window)
            (list (window-edges window) (window-buffer window)))
          (bazooka--sorted-window-list frame)))

(defun bazooka--entries (&optional frame)
  "Return the Bazooka entries belonging to FRAME."
  (frame-parameter (or frame (selected-frame)) bazooka--history-parameter))

(defun bazooka-entries (&optional frame)
  "Return a copy of the Bazooka entries belonging to FRAME.
The entries are ordered from most to least recently remembered."
  (copy-sequence (bazooka--entries frame)))

;;;###autoload
(defun bazooka-clear (&optional frame)
  "Forget every Bazooka entry belonging to FRAME."
  (interactive)
  (set-frame-parameter (or frame (selected-frame))
                       bazooka--history-parameter nil))

(defun bazooka--store-entry (frame entry)
  "Promote ENTRY to the front of FRAME's saved layouts."
  (let* ((signature (bazooka-entry-signature entry))
         (entries (cl-remove signature (bazooka--entries frame)
                             :key #'bazooka-entry-signature
                             :test #'equal))
         (entries (cons entry entries)))
    (set-frame-parameter
     frame bazooka--history-parameter
     (seq-take entries (max 0 bazooka-capacity)))
    entry))

;;;###autoload
(defun bazooka-remember (&optional frame)
  "Remember FRAME's current visible window layout.
Equivalent existing entries are refreshed and promoted instead of duplicated.
Return the new entry, or nil when remembering is disabled or unsafe."
  (interactive)
  (let ((frame (or frame (selected-frame))))
    (when (and (> bazooka-capacity 0)
               (frame-live-p frame)
               (zerop (minibuffer-depth)))
      (with-selected-frame frame
        (bazooka--store-entry
         frame
         (bazooka--make-entry
          :frame frame
          :state (window-state-get (frame-root-window frame) t)
          :signature (bazooka--signature frame)))))))

(defun bazooka--put-state (state frame &optional anchor-window)
  "Restore window STATE on FRAME, preserving the selected window object.
When ANCHOR-WINDOW is live, rebuild the layout around that exact window.  This
keeps Consult's originating window alive across successive previews."
  (let ((chosen (if (window-live-p anchor-window)
                    anchor-window
                  (if (and (eq frame (selected-frame))
                           (not (window-minibuffer-p)))
                      (selected-window)
                    (frame-selected-window frame)))))
    (with-selected-frame frame
      (when (window-minibuffer-p chosen)
        (setq chosen (get-mru-window frame nil 'not-selected)))
      (unless (window-live-p chosen)
        (user-error "Bazooka has no live window to restore into"))
      (select-window chosen)
      (delete-other-windows chosen)
      (window-state-put state chosen 'safe))))

;;;###autoload
(defun bazooka-restore (entry)
  "Restore Bazooka ENTRY without changing the saved-layout list."
  (interactive
   (list (if (require 'consult nil t)
             (bazooka--consult-read)
           (bazooka--completing-read))))
  (unless (bazooka-entry-p entry)
    (user-error "Not a Bazooka entry"))
  (let ((frame (bazooka-entry-frame entry)))
    (unless (frame-live-p frame)
      (user-error "The saved frame no longer exists"))
    (condition-case error-data
        (bazooka--put-state (bazooka-entry-state entry) frame)
      (error
       (user-error "Cannot restore that view: %s"
                   (error-message-string error-data))))))

;;;###autoload
(defun bazooka-toggle ()
  "Remember the current layout, then restore the newest different one.
This is an explicit checkpoint-and-switch operation.  Ordinary buffer and
window changes remain invisible to Bazooka until this command or
`bazooka-remember' is invoked."
  (interactive)
  (bazooka-remember)
  (let ((signature (bazooka--signature)))
    (if-let* ((entry (seq-find
                      (lambda (candidate)
                        (not (equal signature
                                    (bazooka-entry-signature candidate))))
                      (bazooka--entries))))
        (bazooka-restore entry)
      (user-error "Bazooka remembered this view, but has no other saved view"))))

(defun bazooka--entry-buffer-names (entry)
  "Return the live buffer names represented by ENTRY."
  (delete-dups
   (delq nil
         (mapcar (lambda (window-data)
                   (let ((buffer (cadr window-data)))
                     (and (buffer-live-p buffer) (buffer-name buffer))))
                 (bazooka-entry-signature entry)))))

(defun bazooka--entry-label (entry index)
  "Return a display label for ENTRY at saved-layout INDEX."
  (format "%d  %s"
          index
          (or (and-let* ((names (bazooka--entry-buffer-names entry)))
                (string-join names " │ "))
              "<unavailable view>")))

(defun bazooka--items ()
  "Return labeled Bazooka entries for completion."
  (cl-loop for entry in (bazooka--entries)
           for index from 1
           collect (cons (bazooka--entry-label entry index) entry)))

(defun bazooka--completing-read ()
  "Read and return a Bazooka entry with ordinary completion."
  (let ((items (bazooka--items)))
    (unless items
      (user-error "Bazooka has no saved views"))
    (alist-get
     (completing-read "Bazooka view: " items nil t nil
                      'bazooka--consult-history)
     items nil nil #'string=)))

(defun bazooka--consult-state ()
  "Return a Consult state function that previews whole window layouts."
  (let ((origin-frame (selected-frame))
        (origin-window (selected-window))
        (origin-state (window-state-get (frame-root-window) t)))
    (lambda (action candidate)
      (pcase action
        ('preview
         (condition-case error-data
             (progn
               ;; Transition through the invocation layout.  Applying one
               ;; arbitrary tree directly over another can upset dedicated or
               ;; side windows during preview.
               (bazooka--put-state origin-state origin-frame origin-window)
               (when (bazooka-entry-p candidate)
                 (bazooka--put-state (bazooka-entry-state candidate)
                                     (bazooka-entry-frame candidate)
                                     origin-window)))
           (error
            (ignore-errors
              (bazooka--put-state origin-state origin-frame origin-window))
            (message "Bazooka preview unavailable: %s"
                     (error-message-string error-data)))))
        ((or 'exit 'return)
         ;; Consult runs the source action after `return'.  Restore first; the
         ;; action then commits the selected layout.
         (bazooka--put-state origin-state origin-frame origin-window))))))

(defun bazooka--consult-source ()
  "Return the Consult source for saved Bazooka layouts."
  `(:name "Bazooka view"
    :narrow (?v . "View")
    :category bazooka-view
    :face consult-buffer
    :history bazooka--consult-history
    :items ,#'bazooka--items
    :action ,#'identity
    :state ,#'bazooka--consult-state
    :preview-key ,bazooka-preview-key))

(defun bazooka--consult-read ()
  "Read and preview a Bazooka entry with Consult, then return it."
  (unless (bazooka--entries)
    (user-error "Bazooka has no saved views"))
  (car (consult--multi (list (bazooka--consult-source))
                       :prompt "Bazooka view: "
                       :sort nil
                       :require-match t)))

;;;###autoload
(defun bazooka-consult ()
  "Select and preview a saved Bazooka layout with Consult."
  (interactive)
  (unless (require 'consult nil t)
    (user-error "Bazooka's preview picker requires the Consult package"))
  (bazooka-restore (bazooka--consult-read)))

;;;###autoload
(defun bazooka-select ()
  "Select and restore a saved Bazooka layout.
Use Consult with live preview when it is available, and ordinary completion
otherwise."
  (interactive)
  (if (require 'consult nil t)
      (bazooka-consult)
    (bazooka-restore (bazooka--completing-read))))

(provide 'bazooka)
;;; bazooka.el ends here
