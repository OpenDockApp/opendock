PROJECT := OpenDock.xcodeproj
SCHEME  := OpenDock
DERIVED := build

DEBUG_APP   := $(DERIVED)/Build/Products/Debug/OpenDock.app
RELEASE_APP := $(DERIVED)/Build/Products/Release/OpenDock.app

XCB := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED)

.PHONY: help debug prod build-debug build-prod test kill clean

help:
	@echo "make debug        build + launch Debug (OpenDock Debug)"
	@echo "make prod         build + launch Release"
	@echo "make build-debug  build Debug only"
	@echo "make build-prod   build Release only"
	@echo "make test         run OpenDockKit package tests"
	@echo "make kill         quit any running OpenDock"
	@echo "make clean        remove build products"

build-debug:
	$(XCB) -configuration Debug build

build-prod:
	$(XCB) -configuration Release build

debug: build-debug
	open "$(DEBUG_APP)"

prod: build-prod
	open "$(RELEASE_APP)"

test:
	cd Packages/OpenDockKit && swift test

kill:
	-pkill -x OpenDock

clean:
	rm -rf $(DERIVED)
