
;;;;    varint-test.lisp


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


;; Add tests for:
;;   encode-uint32-carefully
;;   encode-uint64-carefully


(defun test-length32()
  (assert (= (length32 0) 1))
  (assert (= (length32 1) 1))
  (assert (= (length32 127) 1))
  (assert (= (length32 128) 2))
  (assert (= (length32 16383) 2))
  (assert (= (length32 16384) 3))
  (assert (= (length32 (ash 1 31)) 5))
  (values))

(defun test-length64 ()
  (assert (= (length64 0) 1))
  (assert (= (length64 1) 1))
  (assert (= (length64 127) 1))
  (assert (= (length64 128) 2))
  (assert (= (length64 16383) 2))
  (assert (= (length64 16384) 3))
  (assert (= (length64 (- (ash 1 21) 1)) 3))
  (assert (= (length64 (ash 1 21)) 4))
  (assert (= (length64 (ash 1 63)) 10))
  (values))

(defun test-encode-parse (n buffer golden encoder parser length)
  (declare (type octet-vector buffer golden)
           (type function encoder parser))
  (let ((encoded-end (funcall encoder buffer 0 n)))
    (assert (= encoded-end length))
    (iter (for i from 0 below encoded-end)
          (assert (= (aref buffer i) (aref golden i))))
    (multiple-value-bind (decoded end)
        (funcall parser buffer 0)
      (assert (= end encoded-end))
      (assert (= decoded n))))
  (values))

(defun test-encode-parse-32 ()
  (let ((n #xe499867)
        (golden '(#xe7 #xb0 #xa6 #x72)))
    (test-encode-parse n
                       (make-octet-vector +max-bytes-32+)
                       (make-octet-vector (length golden)
                                          :initial-contents golden)
                       #'encode-uint32
                       #'parse-uint32
                       (length32 n)))
  (values))

(defun test-encode-parse-64 ()
  (let ((n #xe4998679470d98d)
        (golden '(#x8d #xb3 #xc3 #xa3 #xf9 #x8c #xe6 #xa4 #x0e)))
    (test-encode-parse n
                       (make-octet-vector +max-bytes-64+)
                       (make-octet-vector (length golden)
                                          :initial-contents golden)
                       #'encode-uint64
                       #'parse-uint64
                       (length64 n)))
  (values))

(defun test-encode-parse-skip-extensive ()
  (let ((buffer (make-octet-vector (* 128 +max-bytes-64+)))
        (index 0))

    ;; Encode powers of 2.  Smaller powers are encoded as both 32-bit and
    ;; 64-bit varints.
    (dotimes (p 64)
      (when (< p 32)
        (setf index (encode-uint32 buffer index (ash 1 p))))
      (setf index (encode-uint64 buffer index (ash 1 p))))

    ;; Decode forward.
    (setf index 0)
    (dotimes (p 64)
      (when (< p 32)
        (multiple-value-bind (value32 new-index)
            (parse-uint32 buffer index)
          (assert (= value32 (ash 1 p)))
          (setf index new-index)))
      (multiple-value-bind (value64 new-index)
          (parse-uint64 buffer index)
        (assert (= value64 (ash 1 p)))
        (setf index new-index)))

    ;; Decode backward.  Index already points just past the last value.
    (iter (for p from 63 downto 0)
          (when (< p 32)
            (multiple-value-bind (value32 new-index)
                (parse32-backward buffer index 0)
              (assert (= value32 (ash 1 p)))
              (setf index new-index)))
          (multiple-value-bind (value64 new-index)
              (parse64-backward buffer index 0)
            (assert (= value64 (ash 1 p)))
            (setf index new-index)))
    (assert (zerop index))

    ;; Skip forward.
    (setf index 0)
    (dotimes (p 64)
      (when (< p 32)
        (setf index (skip32 buffer index)))
      (setf index (skip64 buffer index)))

    ;; Skip backwards.
    (iter (for p from 63 downto 0)
          (when (< p 32)
            (setf index (skip32-backward buffer index 0)))
          (setf index (skip64-backward buffer index 0)))
    (assert (zerop index)))

  ;; Encode 1000 random numbers as both 32-bit and 64-bit varints.

  (let* ((trial-count 1000)
         (buffer32 (make-octet-vector (* 1000 +max-bytes-32+)))
         (buffer64 (make-octet-vector (* 1000 +max-bytes-64+)))
         (values32 (make-array trial-count))
         (values64 (make-array trial-count))
         (index32 0)
         (index64 0))
    (dotimes (i trial-count)
      (let* ((value64 (random (ash 1 64)))
             (value32 (ldb (byte 32 0) value64)))
        (setf (aref values32 i) value32)
        (setf (aref values64 i) value64)
        (setf index32 (encode-uint32 buffer32 index32 value32))
        (setf index64 (encode-uint64 buffer64 index64 value64))))

    ;; Decode forward.
    (setf index32 0)
    (setf index64 0)
    (dotimes (i trial-count)
      (multiple-value-bind (value32 new-index)
          (parse-uint32 buffer32 index32)
        (assert (= value32 (aref values32 i)))
        (setf index32 new-index))
      (multiple-value-bind (value64 new-index)
          (parse-uint64 buffer64 index64)
        (assert (= value64 (aref values64 i)))
        (setf index64 new-index)))

    ;; Decode backward.
    (iter (for i from (1- trial-count) downto 0)
          (multiple-value-bind (value32 new-index)
              (parse32-backward buffer32 index32 0)
            (assert (= value32 (aref values32 i)))
            (setf index32 new-index))
          (multiple-value-bind (value64 new-index)
              (parse64-backward buffer64 index64 0)
            (assert (= value64 (aref values64 i)))
            (setf index64 new-index)))
    (values)))

; (defun test-parse32-with-limit ()
;   (let ((buffer (make-octet-vector
;                  10
;                  :initial-contents
;                  '(#x80 #x81 #x82 #x83 #x84 #x85 #x86 #x87 #x88 0))))
;     (should-get-exception?? (parse32-with-limit buffer 0 +max-bytes-32+))))

; (defun test-skip64-backward ()
;   (let ((buffer (make-octet-array
;                  12
;                  :initial-contents
;                  '(#x80 #x81 #x82 #x83 #x84 #x85 #x86 #x87 #x88 #x89
;                    #x80 #x00))))
;     (should-get-exception?? (skip64-backward buffer 11 0))))

(defun test ()
  (test-length32)
  (test-length64)
  (test-encode-parse-32)
  (test-encode-parse-64)
  (test-encode-parse-skip-extensive)
;   (test-parse32-with-limit)
;   (test-skip64-backward)
  (print "PASS")
  (values))
