Yang = require './src'
debug = require 'debug'
s = Yang.compose debug, tag: 'main'
o = s.eval main: debug
