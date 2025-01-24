(define-module (zig-avro-package)
  #:use-module (guix git)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix licenses)
  #:use-module (guix build-system zig)
  #:use-module (gnu packages zig)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu packages base)
  #:use-module ((guix licenses) #:prefix license:))

(define-public zig-avro
  (let ((vcs-file? (or (git-predicate (string-append (current-source-directory) "/../.."))
                       (const #t))))
    (package
      (name "zig-avro")
      (version "0.0.1-git")
      (source (local-file "../.." "zig-avro" #:recursive? #t #:select? vcs-file?))
      (build-system zig-build-system)
      (arguments
       `(#:install-source? #f
         #:tests? #t))
      (inputs (list zig-0.13 zig-zls-0.13))
      (home-page "https://github.com/theothornhill/zig-avro")
      (synopsis "Zig implementation for Apache Avro serde")
      (description "Zero-copy implementation for serializing and deserializing Avro messages.")
      (license license:bsd-2))))

zig-avro
