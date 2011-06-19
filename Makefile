all:
	xcodebuild

clean:
	xcodebuild clean
	rm -rf build

test:
	xcodebuild -target WebSocketTests
