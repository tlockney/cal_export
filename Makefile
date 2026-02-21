PREFIX ?= $(HOME)/.local

AGENT_PLIST = $(HOME)/Library/LaunchAgents/local.cal_export.plist

.PHONY: build release install uninstall install-agent uninstall-agent clean run

build:
	swift build

release:
	swift build -c release

install: release
	mkdir -p $(PREFIX)/bin
	cp .build/release/cal_export $(PREFIX)/bin/cal_export

uninstall:
	rm -f $(PREFIX)/bin/cal_export

install-agent: install
	mkdir -p $(PREFIX)/var
	sed 's|/Users/YOURUSER|$(HOME)|g' local.cal_export.plist > $(AGENT_PLIST)
	launchctl unload $(AGENT_PLIST) 2>/dev/null || true
	launchctl load $(AGENT_PLIST)

uninstall-agent:
	launchctl unload $(AGENT_PLIST) 2>/dev/null || true
	rm -f $(AGENT_PLIST)

clean:
	swift package clean

run:
	swift run cal_export
