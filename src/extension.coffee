# Extension - represents a Yang Extension

Expression = require './expression'

class Extension extends Expression
  constructor: (name, opts={}) ->
    opts.scope ?= {}
    super 'extension', name, opts

module.exports = Extension
