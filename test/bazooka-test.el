;;; bazooka-test.el --- Tests for Bazooka -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'bazooka)

(defmacro bazooka-test--with-clean-frame (&rest body)
  "Run BODY with isolated Bazooka state, then restore the selected frame."
  (declare (indent 0) (debug t))
  `(let ((saved-configuration (current-window-configuration))
         (saved-history (frame-parameter nil bazooka--history-parameter))
         (bazooka-capacity 4))
     (unwind-protect
         (progn
           (bazooka-clear)
           (delete-other-windows)
           ,@body)
       (set-window-configuration saved-configuration)
       (set-frame-parameter nil bazooka--history-parameter saved-history))))

(defun bazooka-test--buffer (name)
  "Return a fresh test buffer named NAME."
  (generate-new-buffer (format " *bazooka-%s*" name)))

(defun bazooka-test--entry-buffer-name (entry)
  "Return the first buffer name represented by ENTRY."
  (car (bazooka--entry-buffer-names entry)))

(ert-deftest bazooka-test-keeps-most-recent-distinct-layouts ()
  (bazooka-test--with-clean-frame
    (let ((buffers (mapcar #'bazooka-test--buffer '(one two three four five))))
      (unwind-protect
          (progn
            (dolist (buffer buffers)
              (switch-to-buffer buffer)
              (bazooka-remember))
            (should (= (length (bazooka-entries)) 4))
            (should (equal (mapcar #'bazooka-test--entry-buffer-name
                                   (bazooka-entries))
                           (mapcar #'buffer-name (reverse (cdr buffers))))))
        (mapc #'kill-buffer buffers)))))

(ert-deftest bazooka-test-revisiting-promotes-without-duplicating ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (switch-to-buffer two)
            (bazooka-remember)
            (switch-to-buffer one)
            (bazooka-remember)
            (should (= (length (bazooka-entries)) 2))
            (should (equal (mapcar #'bazooka-test--entry-buffer-name
                                   (bazooka-entries))
                           (list (buffer-name one) (buffer-name two)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-does-not-record-invisible-buffer-creation ()
  (bazooka-test--with-clean-frame
    (let ((visible (bazooka-test--buffer 'visible))
          hidden)
      (unwind-protect
          (progn
            (switch-to-buffer visible)
            (bazooka-remember)
            (setq hidden (bazooka-test--buffer 'hidden))
            (bazooka-remember)
            (should (= (length (bazooka-entries)) 1))
            (should (eq (window-buffer) visible)))
        (kill-buffer visible)
        (when (buffer-live-p hidden)
          (kill-buffer hidden))))))

(ert-deftest bazooka-test-does-not-record-visible-change-implicitly ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (switch-to-buffer two)
            (should (equal (mapcar #'bazooka-test--entry-buffer-name
                                   (bazooka-entries))
                           (list (buffer-name one)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-distinguishes-window-geometry ()
  (bazooka-test--with-clean-frame
    (let ((left (bazooka-test--buffer 'left))
          (right (bazooka-test--buffer 'right)))
      (unwind-protect
          (progn
            (switch-to-buffer left)
            (bazooka-remember)
            (set-window-buffer (split-window-right) right)
            (bazooka-remember)
            (should (= (length (bazooka-entries)) 2)))
        (kill-buffer left)
        (kill-buffer right)))))

(ert-deftest bazooka-test-zero-capacity-disables-remembering ()
  (bazooka-test--with-clean-frame
    (let ((bazooka-capacity 0))
      (should-not (bazooka-remember))
      (should-not (bazooka-entries)))))

(ert-deftest bazooka-test-toggle-swaps-two-newest-layouts ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (switch-to-buffer two)
            (bazooka-remember)
            (bazooka-toggle)
            (should (eq (window-buffer) one))
            (bazooka-toggle)
            (should (eq (window-buffer) two)))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-toggle-remembers-unsaved-departure-layout ()
  (bazooka-test--with-clean-frame
    (let ((saved (bazooka-test--buffer 'saved))
          (departure (bazooka-test--buffer 'departure)))
      (unwind-protect
          (progn
            (switch-to-buffer saved)
            (bazooka-remember)
            (switch-to-buffer departure)
            (bazooka-toggle)
            (should (eq (window-buffer) saved))
            (should (equal (mapcar #'bazooka-test--entry-buffer-name
                                   (bazooka-entries))
                           (list (buffer-name departure)
                                 (buffer-name saved))))
            (bazooka-toggle)
            (should (eq (window-buffer) departure)))
        (kill-buffer saved)
        (kill-buffer departure)))))

(ert-deftest bazooka-test-first-toggle-remembers-before-erroring ()
  (bazooka-test--with-clean-frame
    (let ((current (bazooka-test--buffer 'current)))
      (unwind-protect
          (progn
            (switch-to-buffer current)
            (should-error (bazooka-toggle) :type 'user-error)
            (should (= (length (bazooka-entries)) 1))
            (should (equal (bazooka-test--entry-buffer-name
                            (car (bazooka-entries)))
                           (buffer-name current))))
        (kill-buffer current)))))

(ert-deftest bazooka-test-restore-does-not-mutate-saved-layouts ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (let ((one-entry (car (bazooka-entries))))
              (switch-to-buffer two)
              (bazooka-remember)
              (let ((before (bazooka-entries)))
                (bazooka-restore one-entry)
                (should (equal (bazooka-entries) before))))
            (should (eq (window-buffer) one)))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-promoted-restores-drive-the-next-toggle ()
  (bazooka-test--with-clean-frame
    (let ((a (bazooka-test--buffer 'a))
          (b (bazooka-test--buffer 'b))
          (c (bazooka-test--buffer 'c)))
      (unwind-protect
          (progn
            ;; Start with A and B as the two newest layouts, with C behind
            ;; them.  This is the state described by the user-facing workflow.
            (dolist (buffer (list c b a))
              (switch-to-buffer buffer)
              (bazooka-remember))
            (let ((a-entry (nth 0 (bazooka-entries)))
                  (c-entry (nth 2 (bazooka-entries))))
              ;; Accepting C and then A in the picker promotes each committed
              ;; selection, resulting in A, C, B MRU order.
              (bazooka-restore c-entry t)
              (bazooka-restore a-entry t)
              (should (equal (mapcar #'bazooka-test--entry-buffer-name
                                     (bazooka-entries))
                             (mapcar #'buffer-name (list a c b))))
              (bazooka-toggle)
              (should (eq (window-buffer) c))))
        (mapc #'kill-buffer (list a b c))))))

(ert-deftest bazooka-test-items-exclude-the-current-layout ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (switch-to-buffer two)
            (bazooka-remember)
            (let ((items (bazooka--items)))
              (should (= (length items) 1))
              (should (equal (bazooka-test--entry-buffer-name (cdar items))
                             (buffer-name one)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-preview-restores-origin-on-cancel ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (let ((one-entry (car (bazooka-entries))))
              (switch-to-buffer two)
              (bazooka-remember)
              (let ((state (bazooka--consult-state)))
                (funcall state 'preview one-entry)
                (should (eq (window-buffer) one))
                (funcall state 'preview nil)
                (should (eq (window-buffer) two))
                (funcall state 'preview one-entry)
                (funcall state 'exit nil)
                (should (eq (window-buffer) two)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-preview-keeps-origin-window-live ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (let ((one-window-entry (car (bazooka-entries))))
              (set-window-buffer (split-window-right) two)
              (select-window (get-buffer-window two))
              (let ((origin-window (selected-window))
                    (state (bazooka--consult-state)))
                (funcall state 'preview one-window-entry)
                (should (window-live-p origin-window))
                (funcall state 'preview nil)
                (should (window-live-p origin-window))
                (should (= (length (window-list)) 2)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-preview-transitions-through-origin ()
  (bazooka-test--with-clean-frame
    (let ((saved (bazooka-test--buffer 'saved)))
      (unwind-protect
          (progn
            (switch-to-buffer saved)
            (bazooka-remember)
            (let ((entry (car (bazooka-entries)))
                  calls)
              (cl-letf (((symbol-function 'bazooka--put-state)
                         (lambda (state frame &optional anchor)
                           (push (list state frame anchor) calls))))
                (let ((preview-state (bazooka--consult-state)))
                  (funcall preview-state 'preview entry)
                  (should (= (length calls) 2))
                  (should (equal (caar calls) (bazooka-entry-state entry)))
                  (should (eq (nth 2 (car calls)) (selected-window)))))))
        (kill-buffer saved)))))

(ert-deftest bazooka-test-preview-return-restores-before-commit ()
  (bazooka-test--with-clean-frame
    (let ((one (bazooka-test--buffer 'one))
          (two (bazooka-test--buffer 'two)))
      (unwind-protect
          (progn
            (switch-to-buffer one)
            (bazooka-remember)
            (let ((one-entry (car (bazooka-entries))))
              (switch-to-buffer two)
              (bazooka-remember)
              (let ((state (bazooka--consult-state)))
                (funcall state 'preview one-entry)
                (funcall state 'return one-entry)
                (should (eq (window-buffer) two))
                (bazooka-restore one-entry)
                (should (eq (window-buffer) one)))))
        (kill-buffer one)
        (kill-buffer two)))))

(ert-deftest bazooka-test-building-items-does-not-remember-current-layout ()
  (bazooka-test--with-clean-frame
    (let ((saved (bazooka-test--buffer 'saved))
          (current (bazooka-test--buffer 'current)))
      (unwind-protect
          (progn
            (switch-to-buffer saved)
            (bazooka-remember)
            (switch-to-buffer current)
            (let ((before (bazooka-entries)))
              (bazooka--items)
              (should (equal (bazooka-entries) before))))
        (kill-buffer saved)
        (kill-buffer current)))))

(ert-deftest bazooka-test-restore-survives-killed-buffer ()
  (bazooka-test--with-clean-frame
    (let ((old (bazooka-test--buffer 'old))
          (current (bazooka-test--buffer 'current)))
      (unwind-protect
          (progn
            (switch-to-buffer old)
            (bazooka-remember)
            (let ((entry (car (bazooka-entries))))
              (switch-to-buffer current)
              (bazooka-remember)
              (kill-buffer old)
              (should-not
               (condition-case nil
                   (progn (bazooka-restore entry) nil)
                 (error t)))))
        (when (buffer-live-p old)
          (kill-buffer old))
        (when (buffer-live-p current)
          (kill-buffer current))))))

(ert-deftest bazooka-test-label-includes-each-visible-buffer ()
  (bazooka-test--with-clean-frame
    (let ((left (bazooka-test--buffer 'left))
          (right (bazooka-test--buffer 'right)))
      (unwind-protect
          (progn
            (switch-to-buffer left)
            (set-window-buffer (split-window-right) right)
            (bazooka-remember)
            (let ((label (bazooka--entry-label (car (bazooka-entries)) 1)))
              (should (string-match-p (regexp-quote (buffer-name left)) label))
              (should (string-match-p (regexp-quote (buffer-name right)) label))))
        (kill-buffer left)
        (kill-buffer right)))))

(ert-deftest bazooka-test-consult-source-uses-current-preview-setting ()
  (let ((bazooka-preview-key "M-."))
    (should (equal (plist-get (bazooka--consult-source) :preview-key)
                   "M-."))))

(ert-deftest bazooka-test-consult-source-does-not-commit-preview-itself ()
  (should (eq (plist-get (bazooka--consult-source) :action) #'identity)))

(ert-deftest bazooka-test-consult-read-unwraps-selected-entry ()
  (bazooka-test--with-clean-frame
    (let ((saved (bazooka-test--buffer 'saved))
          (current (bazooka-test--buffer 'current)))
      (unwind-protect
          (progn
            (switch-to-buffer saved)
            (bazooka-remember)
            (let ((entry (car (bazooka-entries))))
              (switch-to-buffer current)
              (cl-letf (((symbol-function 'consult--multi)
                         (lambda (&rest _arguments)
                           (cons entry '(:name "Bazooka view")))))
                (should (eq (bazooka--consult-read) entry)))))
        (kill-buffer saved)
        (kill-buffer current)))))

(ert-deftest bazooka-test-consult-commits-with-promotion ()
  (let ((entry (bazooka--make-entry))
        restore-arguments
        (consult-was-loaded (featurep 'consult)))
    (unwind-protect
        (progn
          (provide 'consult)
          (cl-letf (((symbol-function 'bazooka--consult-read) (lambda () entry))
                    ((symbol-function 'bazooka-restore)
                     (lambda (&rest arguments)
                       (setq restore-arguments arguments))))
            (bazooka-consult)
            (should (equal restore-arguments (list entry t)))))
      (unless consult-was-loaded
        (setq features (delq 'consult features))))))

(ert-deftest bazooka-test-completing-read-errors-without-layouts ()
  (bazooka-test--with-clean-frame
    (should-error (bazooka--completing-read) :type 'user-error)))

(ert-deftest bazooka-test-picker-errors-when-current-is-only-layout ()
  (bazooka-test--with-clean-frame
    (bazooka-remember)
    (should-error (bazooka--completing-read) :type 'user-error)
    (should-error (bazooka--consult-read) :type 'user-error)))

(provide 'bazooka-test)
;;; bazooka-test.el ends here
