PREFIX ?= $(HOME)/.local

.PHONY: build release install uninstall clean run

build:
	swift build

release:
	swift build -c release

install: release
	mkdir -p $(PREFIX)/bin
	cp .build/release/cal_export $(PREFIX)/bin/cal_export

uninstall:
	rm -f $(PREFIX)/bin/cal_export

clean:
	swift package clean

run:
	swift run cal_export
