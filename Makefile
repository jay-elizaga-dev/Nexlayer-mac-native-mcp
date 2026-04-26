# Mac Native MCP — local build & run
# Usage: make run | make build | make dmg | make open

APP_NAME = MacNativeMCP
BUNDLE   = $(APP_NAME).app

.PHONY: run build open dmg clean

## Quick debug run — builds and launches as proper .app bundle
run:
	swift build 2>&1 | tail -1
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp .build/debug/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - $(BUNDLE)
	open $(BUNDLE)

## Release build
build:
	swift build --configuration release
	@echo "Binary: .build/release/$(APP_NAME)"

## Build release .app bundle and open it
open: build
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp .build/release/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - $(BUNDLE)
	open $(BUNDLE)

## Build .dmg (same as CI)
dmg: build
	@rm -rf $(BUNDLE) dmg_staging $(APP_NAME).dmg
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@cp .build/release/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@mkdir -p dmg_staging
	@cp -r $(BUNDLE) dmg_staging/
	@ln -s /Applications dmg_staging/Applications
	codesign --force --deep --sign - dmg_staging/$(BUNDLE)
	hdiutil create -srcfolder dmg_staging -volname "Mac Native MCP" -format UDZO -o $(APP_NAME).dmg
	@echo "Created: $(APP_NAME).dmg"
	open $(APP_NAME).dmg

## Open in Xcode IDE
xcode:
	open Package.swift

clean:
	rm -rf .build $(BUNDLE) dmg_staging $(APP_NAME).dmg
