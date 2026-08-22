SHELL := /bin/sh

.PHONY: test build app clean

test:
	swift test

build:
	swift build -c release --product Dictate

app:
	./Scripts/build-app.sh

clean:
	rm -rf .build build
