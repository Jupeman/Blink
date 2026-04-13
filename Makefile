.PHONY: generate build run test clean install

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

install: build
	@pkill Blink 2>/dev/null || true
	rm -rf /Applications/Blink.app
	cp -R $(APP_PATH) /Applications/Blink.app
	@echo "Installed to /Applications/Blink.app"

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PROJECT)
