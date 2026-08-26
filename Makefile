SHELL := /bin/sh

.PHONY: test build app benchmark preflight clean

test:
	xcrun swift test

build:
	xcrun swift build -c release --product Dictate

app:
	./Scripts/build-app.sh

benchmark:
	./Scripts/run-benchmark.sh $(ARGS)

preflight:
	./Scripts/release-preflight.sh

clean:
	rm -rf .build build
