# Extension - represents a Yang Extension

Expression = require './expression'

class Bundle extends Expression
  constructor: (name, opts={}) ->
    opts.root = true
    super 'bundle', name, opts

module.exports = Bundle
