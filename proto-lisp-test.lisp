
;;;    proto-lisp-test.lisp


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


(in-package #:proto-lisp-test)


;; XXXX check the code against C++ and Python tests.


(defconst +golden-file-name+ "golden"
  "Name of a file containing correct protocol buffer data.")
(defconst +test-file-name+ "test-output-file"
  "Name of file to which we write protocol buffer data.")

(defmacro assert-string-equal ((field protobuf) string)
  (let* ((field-name (symbol-name field))
         (field-octets (intern (concatenate 'string field-name "-OCTETS")
                               "PROTOCOL-BUFFER")))
    `(progn (assert (equalp (,field ,protobuf) ,string))
            (assert (equalp (,field-octets ,protobuf)
                            (base:string-to-utf8-octets ,string))))))

(defun correctness-tests ()
  ;; Check that required strings are cleared by CLEAR.
  (let ((p (pb:make-TestProtocol)))
    (assert-string-equal (pb:zero p) "")
    (setf (pb:zero p) "x")
    (assert-string-equal (pb:zero p) "x")
    (pb:clear p)
    (assert-string-equal (pb:zero p) ""))

  ;; Check that optional strings are set to their default value by CLEAR.
  (let ((p (pb:make-TestProtocol)))
    (assert-string-equal (pb:optstring p) "opt")
    (setf (pb:optstring p) "x")
    (assert-string-equal (pb:optstring p) "x")
    (pb:clear p)
    (assert-string-equal (pb:optstring p) "opt")
    (setf (pb:optstring p) "x")
    (pb:clear p)
    (assert-string-equal (pb:optstring p) "opt")
    (setf (pb:optstring p) "x")
    (pb:clear-optstring p)
    (assert-string-equal (pb:optstring p) "opt"))
  (values))

(defun test-pb-write ()
  (let ((p (pb:make-Test1Proto)))
    ;; verify enum values
    (assert (= pb:+Test1Proto-FOO+ 0))
    (assert (= pb:+Test1Proto-BAR+ 1))
    (assert (= pb:+Test1Proto-BAZ+ 2))

    ;; default settings
    (assert (= (pb:d_int32 p) 12))
    (assert-string-equal (pb:d_string p) "foo")
    (assert (eq (pb:d_bool p) t))

    ;; test is-initialized
    (assert (not (pb:is-initialized p)))
    (setf (pb:o_a p) 20)
    (assert (pb:is-initialized p))

    ;; unrepeated things
    (setf (pb:u_int32 p) 20)
    (setf (pb:u_int64 p) -20)
    (setf (pb:u_uint64 p) 12345678900)
    (setf (pb:u_fixed32 p) 100)
    (setf (pb:u_fixed64 p) 12345678900)
    (setf (pb:u_bool p) t)
    (setf (pb:u_float p) 3.14159f0)
    (setf (pb:u_double p) 3.14159265d0)
    (setf (pb:u_string p) "foo")
    (setf (pb:u_vardata p) "bar")
    (setf (pb:foo (pb:u_msg p)) 12)

    ;; repeated things
    (vector-push-extend -20 (pb:r_int32 p))
    (vector-push-extend -30 (pb:r_int32 p))
    (vector-push-extend 20 (pb:r_int64 p))
    (vector-push-extend 30 (pb:r_int64 p))
    (vector-push-extend 12345678900 (pb:r_uint64 p))
    (vector-push-extend 98765432100 (pb:r_uint64 p))
    (vector-push-extend 12345 (pb:r_fixed32 p))
    (vector-push-extend 23456 (pb:r_fixed32 p))
    (vector-push-extend 12345678900 (pb:r_fixed64 p))
    (vector-push-extend 98765432100 (pb:r_fixed64 p))
    (vector-push-extend nil (pb:r_bool p))
    (vector-push-extend t (pb:r_bool p))
    (vector-push-extend 1.5f0 (pb:r_float p))
    (vector-push-extend -1.75f0 (pb:r_float p))
    (vector-push-extend 3.3d0 (pb:r_double p))
    (vector-push-extend -1.2d0 (pb:r_double p))
    (vector-push-extend (base:string-to-utf8-octets "foo") (pb:r_string p))
    (vector-push-extend (base:string-to-utf8-octets "bar") (pb:r_string p))
    (vector-push-extend (base:string-to-utf8-octets "ping") (pb:r_vardata p))
    (vector-push-extend (base:string-to-utf8-octets "pong") (pb:r_vardata p))

    (let ((x (pb:make-Test1Msg))
          (y (pb:make-Test1Msg)))
      (setf (pb:foo x) 12)
      (setf (pb:foo y) 13)
      (vector-push-extend x (pb:r_msg p))
      (vector-push-extend y (pb:r_msg p)))

    (let ((x (pb:make-Test1Proto-TestGroup1))
          (y (pb:make-Test1Proto-TestGroup2))
          (z (pb:make-Test1Proto-TestGroup2)))
      (setf (pb:a x) 80)
      (setf (pb:b y) 100)
      (setf (pb:b z) 130)
      (vector-push-extend x (pb:testgroup1 p))
      (vector-push-extend y (pb:testgroup2 p))
      (vector-push-extend z (pb:testgroup2 p)))

    ;; int32 tests
    (loop for x in (list (1- (ash 1 31)) (- (ash 1 31)) 1 0 -1)
          do (vector-push-extend x (pb:r_int32 p)))

    ;; int64 tests
    (loop for x in (list (1- (ash 1 63)) (- (ash 1 63)) 1 0 -1)
          do (vector-push-extend x (pb:r_int64 p)))

    ;; fixed32 tests
    (loop for x in (list -1 (1- (ash 1 31)) 0 1)
          do (vector-push-extend x (pb:r_fixed32 p)))

    ;; fixed64 tests
    (loop for x in (list -1 (1- (ash 1 63)) 0 1)
          do (vector-push-extend x (pb:r_fixed64 p)))

    ;; uint64 tests
    (loop for x in (list (1- (ash 1 64)) (1- (ash 1 63)) 0 1)
          do (vector-push-extend x (pb:r_uint64 p)))

    ;; write buffer to a file
    (let ((size (pb:octet-size p)))
      (let* ((output-buffer (base:make-octet-vector size))
             (end (pb:encode p output-buffer 0 size)))
        (assert (= end size))
        (with-open-file (output-stream +test-file-name+ :direction :output
                                       :if-exists :supersede
                                       :element-type 'unsigned-byte)
          (write-sequence output-buffer output-stream)))

      ;; check against the golden data
      (with-open-file (golden-input +golden-file-name+ :direction :input
                                     :element-type 'unsigned-byte)
        (assert (= (file-length golden-input) size))
        (with-open-file (test-input +test-file-name+ :direction :input
                                     :element-type 'unsigned-byte)
          (assert (= (file-length test-input) size))
          (let ((golden-buffer (base:make-octet-vector size))
                (test-buffer (base:make-octet-vector size)))
            (read-sequence golden-buffer golden-input)
            (read-sequence test-buffer test-input)
            (assert (equalp golden-buffer test-buffer))))))))

(defun test-repeated (value golden)
  (let ((golden-size (length golden)))
    (assert (= (length value) golden-size))
    (loop for v across value
          for g in golden
          ;; V and G are either NIL/T, numbers, or strings, actually simple
          ;; arrays of octets.
          do (cond ((and (member v '(t nil)) (member g '(t nil)))
                    (assert (eq v g)))
                   ((and (numberp v) (numberp g)) (assert (= v g)))
                   ((and (arrayp v) (arrayp g)) (assert (equalp v g)))
                   (t (assert (progn "type mismatch" nil)))))))

(defun test-pb-read ()
  (let ((p (pb:make-Test1Proto)))
    (with-open-file (golden-input +golden-file-name+ :direction :input
                                  :element-type 'unsigned-byte)
      (let* ((size (file-length golden-input))
             (buffer (base:make-octet-vector size)))
        (read-sequence buffer golden-input)
        (assert (= (pb:merge p buffer 0 size) size))))

    ;; unrepeated things
    (assert (pb:has-o_a p))
    (assert (= (pb:o_a p) 20))
    (assert (not (pb:has-o_b p)))
    (assert (= (pb:u_int32 p) 20))
    (assert (= (pb:u_int64 p) -20))
    (assert (= (pb:u_uint64 p) 12345678900))
    (assert (= (pb:u_fixed32 p) 100))
    (assert (= (pb:u_fixed64 p) 12345678900))
    (assert (eq (pb:u_bool p) t))
    (assert (= (pb:u_float p) 3.14159f0))
    (assert (= (pb:u_double p) 3.14159265d0))

    ;; Lisp implementation omits "has" function for embedded messages.
    ;;(assert (has-u_msg p))
    (assert (= (pb:foo (pb:u_msg p)) 12))

    ;; repeated things
    (test-repeated (pb:r_int32 p)
                   (list -20 -30 (1- (ash 1 31)) (- (ash 1 31)) 1 0 -1))
    (test-repeated (pb:r_int64 p)
                   (list 20 30 (1- (ash 1 63)) (- (ash 1 63)) 1 0 -1))
    (test-repeated (pb:r_uint64 p)
                   (list 12345678900 98765432100
                         (1- (ash 1 64)) (1- (ash 1 63))
                         0 1))
    (test-repeated (pb:r_fixed32 p)
                   (list 12345 23456 -1 (1- (ash 1 31)) 0 1))
    (test-repeated (pb:r_fixed64 p)
                   (list 12345678900 98765432100 -1 (1- (ash 1 63)) 0 1))
    (test-repeated (pb:r_bool p) '(nil t))
    (test-repeated (pb:r_float p) '(1.5f0 -1.75f0))
    (test-repeated (pb:r_double p) '(3.3d0 -1.2d0))
    (test-repeated (pb:r_string p)
                   (list (base:string-to-utf8-octets "foo")
                         (base:string-to-utf8-octets "bar")))
    (test-repeated (pb:r_vardata p)
                   (list (base:string-to-utf8-octets "ping")
                         (base:string-to-utf8-octets "pong")))

    (assert (= (length (pb:r_msg p)) 2))
    (assert (= (pb:foo (aref (pb:r_msg p) 0)) 12))
    (assert (= (pb:foo (aref (pb:r_msg p) 1)) 13))

    ;; groups
    (assert (= (length (pb:testgroup1 p)) 1))
    (assert (= (pb:a (aref (pb:testgroup1 p) 0)) 80))

    (assert (= (length (pb:testgroup2 p)) 2))
    (assert (= (pb:b (aref (pb:testgroup2 p) 0)) 100))
    (assert (= (pb:b (aref (pb:testgroup2 p) 1)) 130))

    ;; default settings
    (assert (= (pb:d_int32 p) 12))
    (assert-string-equal (pb:d_string p) "foo")
    (assert (eq (pb:d_bool p) t))))

(defun parser-timing (iterations)
  (let ((src (pb:make-TimeProtocol)))
    (dotimes (i 1000)
      (let ((new (pb:make-TimeProtocol-G)))
        (setf (pb:v1 new) 100)
        (setf (pb:v2 new) 80)
        (vector-push-extend new (pb:g src))))

    (let* ((buffer (base:make-octet-vector 10000))
           (size (pb:encode src buffer 0 10000))) ; XXXXXXXXXX
      (time (dotimes (i iterations)
              (let ((msg (pb:make-TimeProtocol)))
                (pb:merge msg buffer 0 size)))))))

;; XXXXXXXXXXXXXXXXXXXX use parser-timing here

(defun output-timing ())
(defun test-copy-and-merge ())
(defun auto-tests ())

(defun test (&key
             (time-raw-parse nil)
             (time-auto-parse nil)
             (time-raw-output nil)
             (time-auto-output nil)
             (iterations 10000))
  (if (or time-raw-parse time-auto-parse)
      (parser-timing iterations)
      (if (or time-raw-output time-auto-output)
          (output-timing)
          (progn (correctness-tests)
                 (test-pb-write)
                 (test-pb-read)
                 (test-copy-and-merge)
                 ;; XXXX initialize random number generator ??
                 (auto-tests)
                 (print "PASS"))))
  (values))


;; XXXXXXXXXXXXXXXXXXXX add more test code here
