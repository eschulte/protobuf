
;;;;    varint.lisp


;; Copyright 2008, Google Inc.
;; All rights reserved.

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:

;;     * Redistributions of source code must retain the above copyright
;; notice, this list of conditions and the following disclaimer.
;;     * Redistributions in binary form must reproduce the above
;; copyright notice, this list of conditions and the following disclaimer
;; in the documentation and/or other materials provided with the
;; distribution.
;;     * Neither the name of Google Inc. nor the names of its
;; contributors may be used to endorse or promote products derived from
;; this software without specific prior written permission.

;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


(in-package #:varint)


(defconst +max-bytes-32+ 5
  "Maximum number of octets needed to store a 32-bit integer.")
(defconst +max-bytes-64+ 10
  "Maximum number of octets needed to store a 64-bit integer.")


;;; XXXX: Do we really need this many conditions?  Maybe eliminate
;;; varint-error, encoding-error, and/or parsing-error.

(define-condition varint-error (error)
  ()
  (:documentation "Superclass of all VARINT conditions."))


(define-condition encoding-error (varint-error)
  ()
  (:documentation "Superclass of all VARINT encoding conditions."))

(define-condition buffer-overflow (encoding-error)
  ()
  (:documentation "Buffer space exhausted while encoding a value."))


(define-condition parsing-error (varint-error)
  ()
  (:documentation "Superclass of all VARINT decoding conditions."))

(define-condition data-exhausted (parsing-error)
  ()
  (:documentation "Decoding a value requires more data than is available."))

(define-condition value-out-of-range (parsing-error)
  ()
  (:documentation "Value decoded is outside the range of the return type."))

(define-condition alignment (parsing-error)
  ()
  (:documentation "Data buffer does not contain the type of value we have
been asked to skip over or parse backwards."))


(declaim (ftype (function (octet-vector octet-vector-index uint32)
                          octet-vector-index)
                encode-uint32)
         #+opt (inline encode-uint32))

(defun encode-uint32 (buffer index v)
  "Encode V, an unsigned 32-bit integer, into BUFFER at INDEX."
  (declare (type octet-vector buffer)
           (type octet-vector-index index)
           (type uint32 v))
  (when (< v (ash 1 7))
    (setf (aref buffer index) v)
    (incf index)
    (return-from encode-uint32 index))
  (when (< v (ash 1 14))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 7) v))
    (incf index)
    (return-from encode-uint32 index))
  (when (< v (ash 1 21))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 14) v))
    (incf index)
    (return-from encode-uint32 index))
  (when (< v (ash 1 28))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 14) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 21) v))
    (incf index)
    (return-from encode-uint32 index))
  (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 14) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 21) v) 128))
  (incf index)
  (setf (aref buffer index) (ldb (byte 7 28) v))
  (incf index)
  index)

(declaim (ftype (function (octet-vector
                           octet-vector-index
                           octet-vector-index
                           uint32)
                          octet-vector-index)
                encode-uint32-carefully)
         #+opt (inline encode-uint32-carefully))

(defun encode-uint32-carefully (buffer index limit v)
  "Encode V, an unsigned 32-bit integer, into BUFFER at INDEX, taking care
to never write past position LIMIT.  If writing past LIMIT is required to
encode V, then raise ENCODE-OVERFLOW."
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit)
           (type uint32 v))
  (when (< v (ash 1 7))
    (when (>= index limit)
      (error 'buffer-overflow))
    (setf (aref buffer index) v)
    (incf index)
    (return-from encode-uint32-carefully index))
  (when (< v (ash 1 14))
    (when (>= (1+ index) limit)
      (error 'buffer-overflow))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 7) v))
    (incf index)
    (return-from encode-uint32-carefully index))
  (when (< v (ash 1 21))
    (when (>= (+ index 2) limit)
      (error 'buffer-overflow))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 14) v))
    (incf index)
    (return-from encode-uint32-carefully index))
  (when (< v (ash 1 28))
    (when (>= (+ index 3) limit)
      (error 'buffer-overflow))
    (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
    (incf index)
    (setf (aref buffer index) (logior (ldb (byte 7 14) v) 128))
    (incf index)
    (setf (aref buffer index) (ldb (byte 7 21) v))
    (incf index)
    (return-from encode-uint32-carefully index))
  (when (>= (+ index 4) limit)
    (error 'buffer-overflow))
  (setf (aref buffer index) (logior (ldb (byte 7 0) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 7) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 14) v) 128))
  (incf index)
  (setf (aref buffer index) (logior (ldb (byte 7 21) v) 128))
  (incf index)
  (setf (aref buffer index) (ldb (byte 7 28) v))
  (incf index)
  index)

(declaim (ftype (function (octet-vector octet-vector-index uint64)
                          octet-vector-index)
                encode-uint64)
         #+opt (inline encode-uint64))

(defun encode-uint64 (buffer index v)
  "Encode V, an unsigned 64-bit integer, into BUFFER at INDEX."
  (declare (type octet-vector buffer)
           (type octet-vector-index index)
           (type uint64 v))
  (iter (let ((bits (ldb (byte 8 0) v)))
          (setf v (ash v -7))
          (setf (aref buffer index)
                (logior bits (if (not (zerop v)) 128 0)))
          (incf index))
        (while (not (zerop v))))
  index)

(declaim (ftype (function (octet-vector
                           octet-vector-index
                           octet-vector-index
                           uint64)
                          octet-vector-index)
                encode-uint64-carefully)
         #+opt (inline encode-uint64-carefully))

(defun encode-uint64-carefully (buffer index limit v)
  "Encode V, an unsigned 64-bit integer, into BUFFER at INDEX, taking care
to never write past position LIMIT.  If writing past LIMIT is required to
encode V, then raise ENCODE-OVERFLOW."
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit)
           (type uint64 v))
  (iter (let ((bits (ldb (byte 8 0) v)))
          (setf v (ash v -7))
          (when (>= index limit)
            (error 'buffer-overflow))
          (setf (aref buffer index)
                (logior bits (if (not (zerop v)) 128 0)))
          (incf index))
        (while (not (zerop v))))
  index)

(declaim (ftype (function (octet-vector octet-vector-index)
                          (values uint32 octet-vector-index))
                parse-uint32)
         #+opt (inline parse-uint32))

(defun parse-uint32 (buffer index)
  (declare (type octet-vector buffer)
           (type octet-vector-index index))
  (prog* ((byte (prog1 (aref buffer index) (incf index)))
          (result (ldb (byte 7 0) byte)))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 7) result) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 14) result) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 21) result) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 4 28) result) (ldb (byte 4 0) byte))
    (when (< byte 128) (go done))
    (error 'value-out-of-range)
    DONE
    (return (values result index))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint32 octet-vector-index))
                parse-uint32-carefully)
         #+opt (inline parse-uint32-carefully))

(defun parse-uint32-carefully (buffer index limit)
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit))
  (if (<= (+ index +max-bytes-32+) limit)
      (parse-uint32 buffer index)
      (progn
        (when (>= index limit)
          (error 'data-exhausted))
        (prog* ((byte (aref buffer index))
                (result (ldb (byte 7 0) byte)))
           (incf index)
           (when (< byte 128) (go done))
           (when (>= index limit) (go bad))
           (setf byte (prog1 (aref buffer index) (incf index)))
           (setf (ldb (byte 7 7) result) (ldb (byte 7 0) byte))
           (when (< byte 128) (go done))
           (when (>= index limit) (go bad))
           (setf byte (prog1 (aref buffer index) (incf index)))
           (setf (ldb (byte 7 14) result) (ldb (byte 7 0) byte))
           (when (< byte 128) (go done))
           (when (>= index limit) (go bad))
           (setf byte (prog1 (aref buffer index) (incf index)))
           (setf (ldb (byte 7 21) result) (ldb (byte 7 0) byte))
           (when (< byte 128) (go done))
           (when (>= index limit) (go bad))
           (setf byte (prog1 (aref buffer index) (incf index)))
           (setf (ldb (byte 4 28) result) (ldb (byte 4 0) byte))
           (when (< byte 128) (go done))
           (error 'value-out-of-range)
           BAD
           (error 'data-exhausted)
           DONE
           (return (values result index))))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values (unsigned-byte 31) octet-vector-index));XXXX
                parse-uint31-carefully)
         #+opt (inline parse-uint31-carefully))

(defun parse-uint31-carefully (buffer index limit)
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit))
  (multiple-value-bind (result new-index)
      (parse-uint32-carefully buffer index limit)
    (when (= (ldb (byte 1 31) result) 1) ; sign bit set, so value is negative
      (error 'value-out-of-range))
    (values result new-index)))

(declaim (ftype (function (octet-vector octet-vector-index)
                          (values uint64 octet-vector-index))
                parse-uint64)
         #+opt (inline parse-uint64))

(defun parse-uint64 (buffer index)
  (declare (type octet-vector buffer)
           (type octet-vector-index index))
  (prog* ((byte (prog1 (aref buffer index) (incf index)))
          (result1 (ldb (byte 7 0) byte))
          (result2 0)
          (result3 0))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 7) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 14) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 21) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))

    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf result2 (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 7) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 14) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 21) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))

    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf result3 (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 1 7) result3) (ldb (byte 1 0) byte))
    (when (< byte 128) (go done))

    (error 'value-out-of-range)
    DONE
    (return (values (logior result1 (ash result2 28) (ash result3 56))
                    index))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint64 octet-vector-index))
                parse-uint64-carefully)
         #+opt (inline parse-uint64-carefully))

(defun parse-uint64-carefully (buffer index limit)
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit))
  (when (>= index limit)
    (error 'data-exhausted))
  (prog* ((byte (prog1 (aref buffer index) (incf index)))
          (result1 (ldb (byte 7 0) byte))
          (result2 0)
          (result3 0))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 7) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 14) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 21) result1) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))

    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf result2 (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 7) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 14) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 7 21) result2) (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))

    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf result3 (ldb (byte 7 0) byte))
    (when (< byte 128) (go done))
    (when (>= index limit) (go bad))
    (setf byte (prog1 (aref buffer index) (incf index)))
    (setf (ldb (byte 1 7) result3) (ldb (byte 1 0) byte))
    (when (< byte 128) (go done))
    (error 'value-out-of-range)

    BAD
    (error 'data-exhausted)
    DONE
    (return (values (logior result1 (ash result2 28) (ash result3 56))
                    index))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values int64 octet-vector-index))
                parse-int64-carefully)
         #+opt (inline parse-int64-carefully))

(defun parse-int64-carefully (buffer index limit)
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit))
  (multiple-value-bind (result new-index)
      (parse-uint64-carefully buffer index limit)
    (when (= (ldb (byte 1 63) result) 1) ; sign bit set, so value is negative
      (decf result (ash 1 64)))
    (values result new-index)))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values int32 octet-vector-index))
                parse-int32-carefully)
         #+opt (inline parse-int32-carefully))

(defun parse-int32-carefully (buffer index limit)
  (declare (type octet-vector buffer)
           (type octet-vector-index index limit))
  (multiple-value-bind (result new-index)
      (parse-int64-carefully buffer index limit)
    (when (or (>= result (ash 1 31)) (< result (- (ash 1 31))))
      (error 'value-out-of-range))
    (values result new-index)))

(declaim (ftype (function (octet-vector octet-vector-index) octet-vector-index)
                skip32)
         #+opt (inline skip32))

; Well optimized.
(defun skip32 (buffer index)
  (declare (type octet-vector buffer)
           (type octet-vector-index index))
  (prog ()
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (error 'value-out-of-range)
     DONE
     (return (1+ index))))

(declaim (ftype (function (octet-vector octet-vector-index) octet-vector-index)
                skip64)
         #+opt (inline skip64))

; Well optimized.
(defun skip64 (buffer index)
  (declare (type octet-vector buffer)
           (type octet-vector-index index))
  (prog ()
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (incf index)
     (when (< (aref buffer index) 128) (go done))
     (error 'value-out-of-range)
     DONE
     (return (1+ index))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          octet-vector-index)
                skip32-backward-slow))

(defun skip32-backward-slow (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (assert (>= index base))
  (when (or (= index base)
            (> (aref buffer (decf index)) 127))
    (error 'alignment))
  (dotimes (i +max-bytes-32+)
    (when (= index base)
      (return-from skip32-backward-slow index))
    (when (< (aref buffer (decf index)) 128)
      (return-from skip32-backward-slow (1+ index))))
  (error 'alignment))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          octet-vector-index)
                skip64-backward-slow))

(defun skip64-backward-slow (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (assert (>= index base))
  (when (or (= index base)
            (> (aref buffer (decf index)) 127))
    (error 'alignment))
  (dotimes (i +max-bytes-64+)
    (when (= index base)
      (return-from skip64-backward-slow index))
    (when (< (aref buffer (decf index)) 128)
      (return-from skip64-backward-slow (1+ index))))
  (error 'alignment))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          octet-vector-index) skip32-backward)
         #+opt (inline skip32-backward))

(defun skip32-backward (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (if (<= index (+ base +max-bytes-32+))
      (skip32-backward-slow buffer index base)
      (prog ()
         (when (> (aref buffer (decf index)) 127) (go bad))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         BAD
         (error 'value-out-of-range)
         DONE
         (return (1+ index)))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          octet-vector-index) skip64-backward)
         #+opt (inline skip64-backward))

(defun skip64-backward (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (if (<= index (+ base +max-bytes-64+))
      (skip64-backward-slow buffer index base)
      (prog ()
         (when (> (aref buffer (decf index)) 127) (go bad))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         (when (< (aref buffer (decf index)) 128) (go done))
         BAD
         (error 'value-out-of-range)
         DONE
         (return (1+ index)))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint32 octet-vector-index))
                parse32-backward-slow))

(defun parse32-backward-slow (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (let ((prev (skip32-backward-slow buffer index base)))
    (values (parse-uint32 buffer prev) prev)))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint64 octet-vector-index))
                parse64-backward-slow))

(defun parse64-backward-slow (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (let ((prev (skip64-backward-slow buffer index base)))
    (values (parse-uint64 buffer prev) prev)))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint32 octet-vector-index))
                parse32-backward)
         #+opt (inline parse32-backward))

(defun parse32-backward (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (if (<= index (+ base +max-bytes-32+))
      (parse32-backward-slow buffer index base)
      (prog* ((byte (aref buffer (decf index)))
              (result (ldb (byte 7 0) byte)))
         (when (> byte 127) (error 'alignment))

         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))

         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (error 'value-out-of-range)

         DONE
         (return (values result (1+ index))))))

(declaim (ftype (function (octet-vector octet-vector-index octet-vector-index)
                          (values uint64 octet-vector-index))
                parse64-backward)
         #+opt (inline parse64-backward))

(defun parse64-backward (buffer index base)
  (declare (type octet-vector buffer)
           (type octet-vector-index index base))
  (if (<= index (+ base +max-bytes-64+))
      (parse64-backward-slow buffer index base)
      (prog* ((byte (aref buffer (decf index)))
              (result (ldb (byte 7 0) byte)))
         (when (> byte 127) (error 'alignment))

         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))
         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (setf result (logior (ash result 7) (ldb (byte 7 0) byte)))

         (setf byte (aref buffer (decf index)))
         (when (< byte 128) (go done))
         (error 'value-out-of-range)

         DONE
         (return (values result (1+ index))))))

(declaim (ftype (function (uint32) (integer 1 5)) length32)
         #+opt (inline length32))

(defun length32 (v)
  (declare (type uint32 v))
  (setf v (ash v -7))
  (when (zerop v) (return-from length32 1))
  (setf v (ash v -7))
  (when (zerop v) (return-from length32 2))
  (setf v (ash v -7))
  (when (zerop v) (return-from length32 3))
  (setf v (ash v -7))
  (when (zerop v) (return-from length32 4))
  5)

; This version is more compact.  Seems slower for small numbers, same
; or faster for big numbers.

; (declaim (ftype (function (uint32) (integer 1 5)) length32-x)
;          #+opt (inline length32-x))

; (defun length32-x (v)
;   (declare (type uint32 v))
;   (prog ((result 1))
;      (setf v (ash v -7))
;      (when (zerop v) (go done))
;      (incf result)
;      (setf v (ash v -7))
;      (when (zerop v) (go done))
;      (incf result)
;      (setf v (ash v -7))
;      (when (zerop v) (go done))
;      (incf result)
;      (setf v (ash v -7))
;      (when (zerop v) (go done))
;      (incf result)
;      done
;      (return result)))

(declaim (ftype (function (uint64) (integer 1 10)) length64)
         #+opt (inline length64))

(defun length64 (v)
  (declare (type uint64 v))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 1))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 2))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 3))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 4))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 5))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 6))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 7))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 8))
  (setf v (ash v -7))
  (when (zerop v) (return-from length64 9))
  10)
