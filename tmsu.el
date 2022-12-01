;;; tmsu.el --- A basic TMSU interface for Emacs.    -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Wojciech Siewierski

;; Author: Wojciech Siewierski
;; Keywords: files

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A basic TMSU interface for Emacs.
;; See: https://tmsu.org/

;;; Code:

(require 'cl-lib)


(defgroup tmsu nil
  "A basic TMSU interface.")


(defface tmsu-added-face
  '((t (:inherit diff-added)))
  "The faced used to display the added tags.")

(defface tmsu-removed-face
  '((t (:inherit diff-removed)))
  "The face used to display the removed tags.")


(defun tmsu--get-tags (&optional file)
  (split-string-shell-command
   (string-trim-right
    (shell-command-to-string
     (apply #'concat "tmsu tags --name=never --explicit"
            (when file
              (list " " (shell-quote-argument file))))))))

(defun tmsu--get-values (&optional tag)
  (split-string-shell-command
   (string-trim-right
    (shell-command-to-string
     (apply #'concat "tmsu values"
            (when tag
              (list " " (shell-quote-argument tag))))))))

(defun tmsu-database-p ()
  "Check whether a TMSU database exists for the current directory."
  (= (call-process "tmsu" nil nil nil "info") 0))

;;;###autoload
(defun tmsu-edit (file)
  (interactive "f")
  (unless (tmsu-database-p)
    (error "No TMSU database"))
  (let* ((tags-all (tmsu--get-tags))
         (tags-old (tmsu--get-tags file))
         (tags-new (completing-read-multiple "Tags: "
                                             tags-all
                                             nil nil
                                             (string-join tags-old ",")))
         (tags-added (cl-set-difference tags-new tags-old :test #'string=))
         (tags-removed (cl-set-difference tags-old tags-new :test #'string=)))
    (unless (or tags-added
                tags-removed)
      (user-error "No changes"))
    (apply #'call-process
           "tmsu" nil nil nil
           "untag" file
           tags-removed)
    (apply #'call-process
           "tmsu" nil nil nil
           "tag" "--explicit" file
           tags-added)
    (message "%S: %s"
             (tmsu--get-tags file)
             (mapconcat #'identity
                        (nconc (mapcar (lambda (tag)
                                         (concat "-"
                                                 (propertize tag
                                                             'face 'tmsu-removed-face)))
                                       tags-removed)
                               (mapcar (lambda (tag)
                                         (concat "+"
                                                 (propertize tag
                                                             'face 'tmsu-added-face)))
                                       tags-added))
                        " "))))

;;;###autoload
(defun tmsu-edit-dired (parent)
  "Edit the tags of the file at point.

If PARENT is non-nil, edit the current directory instead of
the file at point."
  (interactive "P")
  (let ((file (if parent
                  (dired-current-directory)
                (dired-get-filename t t))))
    (if file
        (tmsu-edit file)
      (user-error "No file on this line"))))

;;;###autoload
(defun tmsu-edit-dired-dwim ()
  (interactive)
  (let* ((file (dired-get-filename t t))
         (is-directory (and file (file-directory-p file))))
    (tmsu-edit-dired (not is-directory))))

;;;###autoload
(defun tmsu-query-dired (query)
  "Display the query results in a virtual dired buffer."
  (interactive (if (tmsu-database-p)
                   (list (completing-read "TMSU query: "
                                          (tmsu--get-tags)))
                 (error "No TMSU database")))
  (with-current-buffer (get-buffer-create "*tmsu*")
    (fundamental-mode)
    (read-only-mode 0)
    (erase-buffer)
    (shell-command (format "tmsu files -0 %s | xargs -0 ls -lhd" (shell-quote-argument query))
                   t)
    (virtual-dired default-directory)
    (setq-local tmsu-query query)
    (setq header-line-format '("tmsu files " tmsu-query))
    (switch-to-buffer (current-buffer))))


(provide 'tmsu)
;;; tmsu.el ends here
