SHELL := /bin/sh

.PHONY: test test-live qmltest lint-shell pycheck smoke

test: lint-shell qmltest pycheck

test-live: test smoke

qmltest:
	./scripts/qml-test.sh

lint-shell:
	./scripts/lint-shell.sh

pycheck:
	./scripts/python-check.sh

smoke:
	./scripts/smoke-load.sh
