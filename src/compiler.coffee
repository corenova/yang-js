indent = require 'indent-string'

Origin = require './origin'
Yin    = require './yin'
Yang   = require './yang'
Synth  = require 'data-synth'

# compiles YIN/YANG schemas
class Compiler extends Origin
  constructor: ->
    super

    @set 'synthesizer', Synth
    @set 'serialize', (obj, opts={}) =>
      opts.format ?= 'yang'
      opts.space  ?= 2
      res = switch opts.format
        when 'yaml' then yaml.dump obj, lineWidth: -1
        when 'yang' then @dump obj, opts.space
        else throw @error "unable to serialize to unknown format: #{opts.format}", obj
      res = switch opts.encoding
        when 'base64' then (new Buffer res).toString 'base64'
        else res
      return res

    unless (Compiler::resolve.call this, 'extension')?
      @define 'extension',
        specification:
          argument: 'name'
          scope:
            global:    '0..1'
            extension: '0..n'
            typedef:   '0..n'
            rpc:       '0..n'
            value:     '0..1'
          preprocess: (arg, params, ctx, compiler) ->
            if params.value?
              data = (new Buffer params.value, 'base64').toString 'binary'
              { schema } = compiler.preprocess data, this
              delete params.value
              @copy params, schema
            @origin.define 'specification', arg, params
          represent:  (arg, obj, opts) ->
            serialize = @resolve 'serialize'
            data = (serialize obj, format: 'yaml', encoding: 'base64')
            "specification #{arg} {#{@dump value: data, opts}}"

        module:
          argument: 'name'
    return this

  #### PRIMARY API METHODS ####

  # produces new compiled object instances generated from provided
  # schema(s)
  #
  # accepts: variable arguments of YANG schema file(s)
  # returns: new Yin object containing compiled schema definitions
  load: ->
    input = [].concat arguments...
    unless input.length > 0
      throw @error "no input schema(s) to load"
    (new Yin this).use input

  #### SECONDARY API METHODS ####

  # process schema/spec input(s) and defines results inside current
  # Compiler instance
  #
  # accepts: variable arguments of YANG/YAML schema/specification string(s)
  # returns: current Compiler instance (with updated definitions)
  use: (origins...) ->
    origins.forEach (x) =>
      switch
        when x instanceof Origin then @set x.map
        else @set (@compile x)
    return this

module.exports = Compiler
