;;; elfeed-dearrow.el --- Elfeed extension to process youtube titles using DeArrow API  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Ivan Popovych

;; Author: Ivan Popovych <ivan@ipvych.com>
;; Package-Requires: (elfeed (emacs "29.1"))
;; Package-Version: 0.1
;; URL: https://github.com/ipvych/elfeed-dearrow

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

;; New entry hook for elfeed to process youtube video titles using DeArrow API
;; with fallback function in case API does not contain suitable title

;;; Code:

(require 'url)
(require 'subr-x)
(require 'elfeed-db)
(require 'elfeed-search)

(defgroup elfeed-dearrow ()
  "Elfeed extension to process youtube titles using DeArrow API."
  :group 'elfeed)

(defcustom elfeed-dearrow-api-url "https://sponsor.ajay.app"
  "URL to DeArrow API."
  :type 'string
  :group 'elfeed-dearrow)

(defcustom elfeed-dearrow-link-regexp "^https://\\(www\.\\)?youtube\\.com/watch.*"
  "Regular expression to match elfeed links on which elfeed-dearrow should work.
May be customized to support invidious instances."
  :type 'regexp
  :group 'elfeed-dearrow)

(defcustom elfeed-dearrow-fallback-function #'elfeed-dearrow-simple-declickbait-entry
  "Function on elfeed entry when DeArrow API did not return any titles.
Function should accept elfeed entry as argument."
  :type 'function
  :group 'elfeed-dearrow)

(defun elfeed-dearrow--set-title (entry title)
  "Set title of elfeed ENTRY to TITLE and redraw it."
  (setf (elfeed-meta entry :title) title)
  (elfeed-search-update-entry entry))

(defun elfeed-dearrow-simple-declickbait-entry (entry)
  "\"Declickbait\" the title of elfeed ENTRY.
Declickbaiting is done by going through following process:
- Convert ALL UPPERCASE words to Title Case
- Remove duplicate ? and !
- Replace occurences of !? or ?! with the first symbol
- Replace all occurences of \"!\" by \".\""
  (let ((title (elfeed-entry-title entry)))
    (elfeed-dearrow--set-title
     entry
     (thread-last
       title
       (elfeed-dearrow-convert-uppercase-to-titlecase-maybe)
       (elfeed-dearrow-remove-duplicate-punctuation)
       (string-replace "!" ".")))))

(defun elfeed-dearrow-convert-uppercase-to-titlecase-maybe (string)
  "Return STRING with ALL UPPERCASE words converted to Title Case.
Single-letter words in STRING are kept as-is."
  (mapconcat
   (lambda (word)
     (if (and (> (length word) 1) (elfeed-dearrow--string-uppercase-p word))
         (capitalize word)
       word))
   (split-string string) " "))

(defun elfeed-dearrow--string-uppercase-p (string)
  "Return non-nil if all letters in STRING are uppercase."
  (let ((letters (replace-regexp-in-string "[[:punct:]]*" "" string)))
    (and (> (length letters) 0) (cl-every #'char-uppercase-p letters))))

(defun elfeed-dearrow-remove-duplicate-punctuation (string)
  "Remove duplicated punctuation symbols from STRING."
  (let ((punctuation '(?? ?!)))
    (cl-loop
     with prev = nil
     for char across string
     when (not (and (member char punctuation) (member prev punctuation)))
     collect char into x
     do (setq prev char)
     finally return (apply #'string x))))

(defun elfeed-dearrow-update-title (entry)
  "Update title of elfeed ENTRY using DeArrow API."
  (when-let* ((url (elfeed-entry-link entry))
              (_ (string-match-p elfeed-dearrow-link-regexp url))
              (video-id (elfeed-dearrow-extract-video-id url)))
    (url-retrieve (elfeed-dearrow-fetch-url video-id)
                  #'elfeed-dearrow--update-title-callback
                  (list entry video-id)
                  :silent)))

(defun elfeed-dearrow-extract-video-id (url)
  "Return youtube video hash from URL."
  (let* ((parsed-url (url-generic-parse-url url))
         (query (cdr (url-path-and-query parsed-url))))
    (when-let (id-arg (assoc "v" (url-parse-query-string query)))
      (car (cdr id-arg)))))

(defun elfeed-dearrow-fetch-url (video-id)
  "Return url to fetch DeArrow titles for VIDEO-ID."
  (let* ((video-hash (secure-hash 'sha256 video-id))
         (search-hash (truncate-string-to-width video-hash 4)))
    (format "%s/api/branding/%s" elfeed-dearrow-api-url search-hash)))

(defun elfeed-dearrow--update-title-callback (_ entry video-id)
  "Callback function for `elfeed-dearrow-update-title' receiving elfeed ENTRY and VIDEO-ID."
  (re-search-forward "HTTP/[.0-9]+ +\\([0-9]+\\)")
  (when (= (string-to-number (match-string 1)) 200)
    (goto-char url-http-end-of-headers)
    (let* ((data (json-read))
           (video-data (alist-get (intern video-id) data))
           (titles (alist-get 'titles video-data)))
      (if (> (length titles) 0)
          (elfeed-dearrow--set-title entry (alist-get 'title (seq-first titles)))
        (when elfeed-dearrow-fallback-function
          (funcall elfeed-dearrow-fallback-function entry))))))

(provide 'elfeed-dearrow)
;;; elfeed-dearrow.el ends here
