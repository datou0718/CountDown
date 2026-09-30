.PHONY: build install test run

build:
	bash scripts/build.sh

test:
	bash scripts/test.sh

install: build
	bash scripts/install.sh

run: install
	open "$(HOME)/Applications/Count Down.app"
