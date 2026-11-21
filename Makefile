# Lily-ios entry points. The Xcode project is generated from project.yml (brew install xcodegen).
SIM := platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5
.PHONY: project build test lint check clean device
project:
	xcodegen generate --quiet
build: project
	xcodebuild -project Lily.xcodeproj -scheme Lily -destination '$(SIM)' build | tail -5
test: project
	xcodebuild -project Lily.xcodeproj -scheme Lily -destination '$(SIM)' test | tail -15
lint:
	./scripts/security-lint.sh
check: lint test
clean:
	rm -rf Lily.xcodeproj build
# On your own device with a free Apple ID: see docs/DEVICE.md
device: project
	@test -f Config/Local.xcconfig || { echo "create Config/Local.xcconfig first (docs/DEVICE.md)"; exit 1; }
	xcodebuild -project Lily.xcodeproj -scheme Lily -destination 'generic/platform=iOS' -allowProvisioningUpdates build | tail -5
