.PHONY: generate build run test clean

PROJECT = Blink.xcodeproj
SCHEME = Blink
BUILD_DIR = build
APP_PATH = $(BUILD_DIR)/Build/Products/Release/Blink.app

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build

debug: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build

run: build
	open $(APP_PATH)

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		test

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PROJECT)
