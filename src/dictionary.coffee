synth = require 'data-synth'

class Dictionary

  constructor: (@parent) -> @map = {}

  load: -> synth.copy @map, x for x in arguments when x instanceof Object; return this

  define: (type, key, value, global=false) ->
    exists = @resolve type, key, false
    definition = synth.objectify "#{type}.#{key}", switch
      when not exists?             then value
      when synth.instanceof exists then exists.merge value
      when synth.instanceof value  then value.override exists
      when exists.constructor is Object
        synth.copy exists, value
      else
        throw @error "unable to define #{type}.#{key} due to conflict with existing definition", exists
    synth.copy @map, definition
    return this

  resolve: (type, key, warn=true) ->
    #console.log "resolve #{type}:#{key}"
    unless key?
      # TODO: we may want to grab other definitions from imported modules here
      return @map[type] ? @parent?.resolve? type

    [ prefix..., key ] = key.split ':'
    match = switch
      when prefix.length > 0 then @map[prefix[0]]?[type]?[key]
      else @map[type]?[key]
    match ?= @parent?.resolve? arguments...
    unless match?
      console.log "[resolve] unable to find #{type}:#{key}" if warn
    return match

  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    #console.log "locating #{path}"
    if inside.access instanceof Function
      return switch
        when target is '..'
          if (inside.parent.meta 'synth') is 'list'
            @locate inside.parent.parent, rest.join '/'
          else
            @locate inside.parent, rest.join '/'
        when rest.length > 0 then @locate (inside.access target), rest.join '/'
        else inside.access target

    for key, val of inside when val.hasOwnProperty target
      return switch
        when rest.length > 0 then @locate val[target], rest.join '/'
        else val[target]
    console.warn "[locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  error: (msg, context) ->
    res = new Error msg
    res.context = context
    return res

module.exports = Dictionary
