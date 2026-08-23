SHELL := /bin/sh

.PHONY: test build app clean

test:
	xcrun swift test

build:
	xcrun swift build -c release --product Dictate

app:
	./Scripts/build-app.sh

clean:
	rm -rf .build build
