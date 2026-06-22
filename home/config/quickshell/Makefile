SHELL := /bin/sh

.PHONY: format lint test test-live qmltest lint-shell pycheck smoke smoke-system integration-smoke migration-check arch-check cutover-status review refresh-review-evidence verify ci-verify

format:
	sh ./scripts/format.sh

lint:
	sh ./scripts/lint.sh

test: qmltest pycheck

test-live: test smoke integration-smoke

verify:
	sh ./scripts/verify.sh

ci-verify:
	CI=1 sh ./scripts/verify.sh

arch-check:
	sh ./scripts/arch-check.sh

cutover-status:
	sh ./scripts/cutover-status.sh

review:
	sh ./scripts/review.sh

refresh-review-evidence:
	sh ./scripts/refresh-review-evidence.sh

qmltest:
	./scripts/qml-test.sh

lint-shell:
	./scripts/lint-shell.sh

pycheck:
	./scripts/python-check.sh

smoke:
	./scripts/smoke-load.sh

smoke-system:
	./scripts/smoke-load.sh

integration-smoke:
	sh ./scripts/integration-smoke.sh

migration-check:
	./scripts/migration-check.sh
