.PHONY: lint
lint:
	luacheck --config=.luacheckrc --no-unused-args --no-redefined \
	                    ./lib/template.lua

.PHONY: test
test:
	./tests/template.lua

.PHONY: build
build:
	tarantoolctl rocks make

all: build
