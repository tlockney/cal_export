.PHONY: build release install uninstall clean run

build:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/cal_export /usr/local/bin/cal_export

uninstall:
	rm -f /usr/local/bin/cal_export

clean:
	swift package clean

run:
	swift run cal_export
