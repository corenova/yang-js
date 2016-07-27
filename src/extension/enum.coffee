Extension  = require '../extension'

module.exports =
  new Extension 'enum',
    argument: 'name'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      value:       '0..1'
      
    resolve: -> 
      @parent.enumValue ?= 0
      unless @value?
        @extends "value #{@parent.enumValue++};"
      else
        cval = (Number @value.tag) + 1
        @parent.enumValue = cval unless @parent.enumValue > cval
