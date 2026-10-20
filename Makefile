.PHONY: lint test

lint:
	shellcheck bash/*.sh

test:
	bats bash/tests/