# TODO: we should try to eliminate this dependency
synth = require 'data-synth'

class Origin

  constructor: (@origin) -> @map = {}

  set: (keys..., value) ->
    obj = synth.objectify (keys.join '.'), value
    synth.copy @map, obj if obj instanceof Object;
    return this

  # returns the 'updated' defined object
  define: (keys..., value) ->
    exists = @resolve keys[0], keys[1], warn: false
    definition = synth.objectify (keys.join '.'), switch
      when not exists?             then value
      when synth.instanceof exists then exists.merge value
      when synth.instanceof value  then value.override exists
      when exists.constructor is Object
        synth.copy exists, value
      else
        throw @error "unable to define #{keys.join '.'} due to conflict with existing definition", exists
    @set definition
    return definition

  # TODO: enable resolve to merge nested definitions when only one key...
  resolve: (keys..., opts={}) ->
    unless opts instanceof Object
      keys.push opts
      opts = {}
    return unless keys.length > 0

    # setup default opts
    opts.warn ?= true
    opts.recurse ?= true

    [ type, key ] = keys
    [ prefix..., key ] = (key?.split ':') ? []
    match = switch
      when not key? then @map[type]
      when prefix.length > 0 then @map[prefix[0]]?[type]?[key]
      else @map[type]?[key]
    match ?= @origin?.resolve? arguments... if opts.recurse is true
    unless match?
      console.debug? "[Origin:resolve] unable to find #{type}:#{key}" if opts.warn
    return match

  # convenience function
  copy: synth.copy

  error: (msg, context) ->
    res = new Error msg
    res.context = context ? @map
    return res

  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Origin:locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Origin:locate] locating #{path}"
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
    console.warn "[Origin:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

module.exports = Origin
