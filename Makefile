PROJECT := StopwatchUtility.xcodeproj
SCHEME := StopwatchUtility
CONFIGURATION ?= Debug
DERIVED_DATA ?= .build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Pomotimer.app
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO

.PHONY: build run test clean

build:
	$(XCODEBUILD) build

run: build
	open "$(APP_PATH)"

test:
	$(XCODEBUILD) test

clean:
	$(XCODEBUILD) clean
