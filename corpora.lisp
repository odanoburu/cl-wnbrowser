;; -*- mode: common-lisp -*-

;; Copyright (c) 2015 The OpenWordNet-PT project
;; This program and the accompanying materials are made available
;; under the terms described in the LICENSE file.

(in-package :cl-wnbrowser)

(defparameter *words-pt-suggestions* nil)
(defparameter *words-pt-wn* nil)
(defparameter *words-en-wn* nil)

(defun cache-words (&key (core-only nil))
  (flet ((get-synset-words (synset)
	   (let ((synset-id (getf synset :|doc_id|)))
	     (dolist (w (get-pt-words synset))
	       (push synset-id (gethash w *words-pt-wn*)))
	     (dolist (w (get-en-words synset))
	       (push synset-id (gethash w *words-en-wn*)))))
	 (get-suggestion-words (suggestions)
	   (dolist (suggestion suggestions)
	     (let ((synset-id (getf suggestion :|doc_id|)))
	       (push synset-id (gethash (getf suggestion :|params|)
					*words-pt-suggestions*))))))
    (setf *words-pt-suggestions* (make-hash-table :test #'equal :size 200000))
    (setf *words-en-wn* (make-hash-table :test #'equal :size 150000))
    (setf *words-pt-wn* (make-hash-table :test #'equal :size 150000))
    (mapc #'get-synset-words (remove-if-not #'verb? (hash-table-values *wn*)))
    (mapc #'get-suggestion-words (hash-table-values *word-suggestions*))
    t))

(defun init-corpora ()
  (cache-words)
  (load-verbnet)
  (load-dhbb)
  (load-verbocean)
  (load-pt-ud)
  (load-portal-da-lingua-portuguesa))
  
(defparameter *portal-da-lingua-portuguesa* nil)
(defparameter *verbnet* nil)
(defparameter *verbocean* nil)
(defparameter *dhbb* nil)
(defparameter *pt-ud* nil)

(defun load-complex-corpus (filename hashtable)
  (fare-csv:with-rfc4180-csv-syntax ()
    (dolist (row (fare-csv:read-csv-file filename :external-format :utf-8))
      (let ((pt (trim (first row)))
	    (en (trim (second row))))
        (when (> (length pt) 0)
          (push en (gethash pt hashtable)))))))

(defun load-simple-corpus (filename hashtable)
  (with-open-file (stream filename  :external-format :utf-8)
    (do ((line (read-line stream nil)
               (read-line stream nil)))
        ((null line))
      (let ((trimmed-line (trim line)))
        (when (> (length trimmed-line) 0)
          (setf (gethash (trim line) hashtable) nil))))))

(defun load-verbnet ()
  (setf *verbnet* (make-hash-table :test #'equal :size 15000))
  (load-complex-corpus  (merge-pathnames "corpora/verbnet.br.csv" *basedir*) *verbnet*))

(defun load-verbocean ()
  (setf *verbocean* (make-hash-table :test #'equal :size 15000))
  (load-complex-corpus (merge-pathnames "corpora/verbocean-translated.csv" *basedir*) *verbocean*))

(defun load-dhbb ()
  (setf *dhbb* (make-hash-table :test #'equal :size 15000))
  (load-complex-corpus (merge-pathnames "corpora/verbos-DHBB.csv" *basedir*) *dhbb*))

(defun load-portal-da-lingua-portuguesa ()
  (setf *portal-da-lingua-portuguesa* (make-hash-table :test #'equal :size 15000))
  (load-simple-corpus (merge-pathnames "corpora/portal-da-lingua-pt.txt" *basedir*) *portal-da-lingua-portuguesa*))

(defun load-pt-ud ()
  (setf *pt-ud* (make-hash-table :test #'equal :size 15000))
  (load-simple-corpus (merge-pathnames "corpora/pt-ud.txt" *basedir*) *pt-ud*))

(defun get-similar-words (word)
  (append (remove-if-not (lambda (x)
		   (> (mk-string-metrics:norm-damerau-levenshtein x word) .9))
			 (hash-table-keys *words-pt-wn*))
	  (remove-if-not (lambda (x)
			   (> (mk-string-metrics:norm-damerau-levenshtein x word) .9))
			 (hash-table-keys *words-pt-suggestions*))))

(defun get-possible-synsets (pt-word corpus)
  (let ((synsets nil))
    (dolist (en-word (gethash pt-word corpus))
      (dolist (s (gethash en-word *words-en-wn*))
	(push s synsets)))
    synsets))

(defun check-corpus (corpus)
  (let ((result nil)
	(total 0)
	(in-wn 0)
	(in-suggestions 0))
    (dolist (word (hash-table-keys corpus))
      (incf total)
      (if (gethash word *words-pt-suggestions*)
	  (incf in-suggestions)
	  (if (gethash word *words-pt-wn*)
	      (incf in-wn)
	      (push (list :word word
			  :synsets (get-possible-synsets word corpus))
		    result))))
    (list :total total :totalwn in-wn :totalsuggestions in-suggestions :words result)))

(defun check-portal-da-lingua-portuguesa ()
  (check-corpus *portal-da-lingua-portuguesa*))

(defun check-verbnet ()
  (check-corpus *verbnet*))

(defun check-dhbb ()
  (check-corpus *dhbb*))

(defun check-verbocean ()
  (check-corpus *verbocean*))

(defun check-pt-ud ()
  (check-corpus *pt-ud*))
