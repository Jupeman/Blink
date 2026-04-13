.PHONY: generate build debug run test clean install release

PROJECT = Blink.xcodeproj
SCHEME = Blink
BUILD_DIR = build
APP_PATH = $(BUILD_DIR)/Build/Products/Release/Blink.app
NOTARY_PROFILE = Blink
ZIP_PATH = $(BUILD_DIR)/Blink.zip

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

release: build
	@echo "==> Signing..."
	codesign --force --deep --options runtime \
		--sign "Developer ID Application: Charles Boyer (M7WYS8QB7Z)" \
		$(APP_PATH)
	@echo "==> Creating zip for notarization..."
	rm -f $(ZIP_PATH)
	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)
	@echo "==> Submitting to Apple for notarization..."
	xcrun notarytool submit $(ZIP_PATH) \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo "==> Stapling notarization ticket..."
	xcrun stapler staple $(APP_PATH)
	@echo "==> Done. $(APP_PATH) is signed and notarized."

install: release
	@pkill Blink 2>/dev/null || true
	rm -rf /Applications/Blink.app
	cp -R $(APP_PATH) /Applications/Blink.app
	@echo "Installed to /Applications/Blink.app"

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PROJECT)
