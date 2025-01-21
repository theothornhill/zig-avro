(use-modules (guix git)
             (guix gexp)
             (guix git-download)
             (guix utils)
             (guix packages)
             (guix licenses)
             (guix build-system zig)
             (gnu packages zig)
             (gnu packages zig-xyz)
             (gnu packages base)
             ((guix licenses) #:prefix license:))

(define vcs-file?
  (or (git-predicate (current-source-directory))
      (const #t)))

(package
 (name "zig-avro")
 (version "0.0.1")
 (source (local-file "." "zig-avro" #:recursive? #t #:select? vcs-file?))
 (build-system zig-build-system)
 (arguments
  `(#:install-source? #f
    #:tests? #t))
 (inputs (list
          zig-0.13
          zig-zls-0.13))
 (home-page "https://ziglang.org/")
 (synopsis "General-purpose programming language and toolchain")
 (description "Zig is a general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software.")
 (license license:bsd-2))
