.PHONY: build install test check run

build:
	bash scripts/build.sh

test:
	bash scripts/test.sh

check: test build
	bash scripts/verify-bundle.sh

install: build
	bash scripts/install.sh

run: install
	open "$(HOME)/Applications/Count Down.app"
