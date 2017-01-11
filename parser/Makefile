.PHONY: test

all: lib/yang-parser.js

lib/yang-parser.js: src/yang-parser.litcoffee
	coffee -o lib -c $<

test:
	@coffee test/test.coffee
