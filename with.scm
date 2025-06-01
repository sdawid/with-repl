#!/usr/bin/env -S guile -e main
!#

(use-modules
  (ice-9 match)
  (ice-9 popen)
  (ice-9 readline)
  (ice-9 regex)
  (ice-9 textual-ports)
  (srfi srfi-9)) ; records


;;; Utils ---------------------------------------------------------------------

(define (drop-head xs n)
  (cond
    [(null? xs) '()]
    [(<= n 0) xs]
    [else (drop-head (cdr xs) (1- n))]))


(define (drop-tail xs n)
  (reverse (drop-head (reverse xs) n)))


(define (strip-first-char s)
  (let ([l (string-length s)])
    (substring s (min 1 l) l)))


(define (strip-last-char s)
  (let ([l (string-length s)])
    (substring s 0 (max 0 (1- l)))))


(define (string-tokens line)
  (filter
    (lambda (s) (not (string-null? s)))
    (string-split line #\ )))

;;; Test Utils ----------------------------------------------------------------

(define-syntax assert-equal?
  (syntax-rules ()
    ((_ arg1 arg2)
     (let ((a1 arg1) (a2 arg2))
       (unless (equal? a1 a2)
         (error (format #f "expected: (equal? ~s ~s)~% but was: (equal? ~s ~s)"
                        'arg1 'arg2 a1 a2)))))))


;;; Prompt --------------------------------------------------------------------

(define *max-prompt* (make-parameter 42))

(define (bounded-string s max-len)
  (let ([s-len (string-length s)])
    (if (> s-len max-len)
      (string-append
        ".."
        (substring s (- s-len max-len -2)))
      s)))


(define (format-prompt ctx buf)
  (if (equal? "" buf)
      (bounded-string
        (string-append (string-join ctx) "> ")
        (*max-prompt*))
      "... "))


(define (test-format-prompt)
  (assert-equal? "a b> " (format-prompt '("a" "b") ""))
  (assert-equal? "... " (format-prompt '("a" "b") "foobar"))
  (parameterize ([*max-prompt* 7])
    (assert-equal? "12345> " (format-prompt '("12345") ""))
    (assert-equal? "..456> " (format-prompt '("123456") ""))))




;;; Logic ---------------------------------------------------------------------

; REPL loop logic - applies imput to the REPL state
; string string string -> action
; where action:
; - ('exit)
; - ('execute cmd line)
; - ('continue cmd line)
; - ('setenv cmd line name value)
(define (handle-input ctx buf input)
  (let ((line (string-append buf input)))
    (cond
      ((string-match "\\\\$" line)
       (list 'new-buf (strip-last-char line)))
      ((string-match "^\\+" line)
       (list 'new-ctx (append ctx (string-tokens (strip-first-char line)))))
      ((string-match "^-+$" line)
       (let ((ctx (drop-tail ctx (string-length line))))
         (if (null? ctx)
           (list 'exit)
           (list 'new-ctx ctx))))
      ((string-match "^\\! *([a-zA-Z_0-9]+) *=(.*)$" line)
       => (λ (m) (list 'set-env
                       (string-trim-both (match:substring m 1))
                       (string-trim-both (match:substring m 2)))))
      ((string-match "^\\!" line)
       (list 'execute (strip-first-char line)))
      ((equal? "" line)
       (list 'nop))
      (else
       (list 'execute (string-append (string-join ctx) " " line))))))


(define (test-handle-input)
  ; non empty buf+input - execute a command
  (assert-equal? '(nop)
                 (handle-input '("a" "b") "" ""))
  (assert-equal? '(execute "a b c d")
                 (handle-input '("a" "b") "c d" ""))
  (assert-equal? '(execute "a b c de")
                 (handle-input '("a" "b") "c d" "e"))
  (assert-equal? '(execute "a b  c d ")
                 (handle-input '("a" "b") "" " c d "))

  ; line starting with '+' - append tokens to a command
  (assert-equal? '(new-ctx ("a" "b" "c"))
                 (handle-input '("a") "" "+ b  c  "))
  (assert-equal? '(new-ctx ("a" "bc"))
                 (handle-input '("a") "+b" "c"))
  (assert-equal? '(new-ctx ("a" "b" "c"))
                 (handle-input '("a") "+b" " c"))

  ; line containing only '-' - remove base tokens
  ; when there are no base tokens left - exit
  (assert-equal? '(new-ctx ("a"))
                 (handle-input '("a" "b") "" "-"))
  (assert-equal? '(exit)
                 (handle-input '("a" "b") "" "--"))
  (assert-equal? '(exit)
                 (handle-input '("a" "b") "" "---"))

  ; multiline command - appends input to the buf
  (assert-equal? '(new-buf "b")
                 (handle-input '("a") "" "b\\"))
  (assert-equal? '(new-buf "  b  ")
                 (handle-input '("a") "" "  b  \\"))
  (assert-equal? '(new-buf "bc")
                 (handle-input '("a") "b" "c\\"))
  (assert-equal? '(new-buf "bc ")
                 (handle-input '("a") "b" "c \\"))
  (assert-equal? '(new-buf "a")
                 (handle-input '("a") "a" "\\"))

  ; execute new shell subcommand
  (assert-equal? '(execute "b")
                 (handle-input '("a") "" "!b"))
  (assert-equal? '(execute "bc")
                 (handle-input '("a") "!b" "c"))

  ; set env variable
  (assert-equal? '(set-env "FOO" "123")
                 (handle-input '("a") "" "!FOO=123"))
  (assert-equal? '(set-env "foo" "")
                 (handle-input '("a") "" "!  foo =  ")))



;;; REPL Loop -----------------------------------------------------------------

(define (execute-command command)
  (let ((exit-code (system command)))
    (if (not (= 0 exit-code)) (newline))))


(define (evaluate-envars value)
  (call-with-port
    (open-input-pipe
      (string-append "echo " value))
    get-string-all))


(define (repl-loop ctx buf)
  (let ((input (readline (format-prompt ctx buf))))
    (when (not (eof-object? input))
      (add-history input)
      (match (handle-input ctx buf input)
        (('execute cmd)
         (execute-command cmd)
         (repl-loop ctx ""))
        (('set-env name value)
         (setenv name (evaluate-envars value))
         (repl-loop buf ""))
        (('new-buf buf)
         (repl-loop ctx buf))
        (('new-ctx ctx)
         (repl-loop ctx ""))
        (('nop)
         (repl-loop ctx buf))
        (('exit) #f)))))


(define (main args)
  (clear-history)
  (repl-loop (cdr args) ""))


(define (test args)
  (test-format-prompt)
  (test-handle-input))
