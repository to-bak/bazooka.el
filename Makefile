EMACS ?= emacs
EMACS_BATCH = $(EMACS) -Q --batch

.PHONY: all check test compile checkdoc lint clean

all: check

check: compile checkdoc test

test:
	$(EMACS_BATCH) -L . -L test \
	  -l bazooka-test \
	  -f ert-run-tests-batch-and-exit

compile:
	$(EMACS_BATCH) -L . \
	  --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile bazooka.el

checkdoc:
	$(EMACS_BATCH) -L . \
	  --eval '(progn (require (quote checkdoc)) (checkdoc-file "bazooka.el"))'

# Requires package-lint, available from MELPA.
lint:
	$(EMACS_BATCH) \
	  --eval '(progn (require (quote package)) (package-initialize))' \
	  -l package-lint \
	  -f package-lint-batch-and-exit bazooka.el

clean:
	$(RM) bazooka.elc test/*.elc
