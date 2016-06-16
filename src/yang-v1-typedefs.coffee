#
# YANG version 1.0 built-in TYPEDEFs
#
Expression = require './expression'
Typedef    = Expression.bind null, 'typedef'

module.exports = [

  new Typedef 'binary',
    construct: (value) ->
      return unless value?
      unless value instanceof Function
        throw @error "value not a binary instance", value
      value

  new Typedef 'boolean',
    construct: (value) ->
      return unless value?
      if typeof value is 'string' 
        unless value in [ 'true', 'false' ]
          throw new Error "boolean value must be 'true' or 'false'"
        value is 'true'
      else
        Boolean value

  new Typedef 'decimal64',
    construct: (value) ->
      return unless value?
      if Number.isNaN (Number value)
        throw new Error "#{@tag} unable to construct '#{value}'"
      Number value

  new Typedef 'empty',
    construct: (value) -> null

  new Typedef 'enumeration',
    construct: (value) ->
      return unless value?
      unless @enum?.length > 0
        throw new Error "#{@tag} enumeration must have one or more 'enum' definitions"
      for i in @enum
        return i.tag if value is i.tag
        return i.tag if value is i.value.tag
        return i.tag if "#{value}" is i.value.tag
      throw new Error "#{@tag} enumeration type violation for '#{value}' on #{@enum.map (x) -> x.tag}"

  # TODO
  new Typedef 'identityref',
    construct: (value) ->
      return unless value?
      unless @base? and typeof @base.tag is 'string'
        throw new Error "identityref must reference 'base' identity"
      identity = @base.tag
      # return a computed function (runs during get)
      func = ->
        match = @expr.lookup 'identity', value
        # TODO - need to figure out how to return namespace value...
        unless (match? and identity is match.base?.tag)
          new Error "#{@name} identityref is invalid for '#{value}'"
        else
          value
      func.computed = true
      return func

  # TODO
  new Typedef 'instance-identifier',
    construct: (value) ->

  new Typedef 'leafref',
    construct: (value) ->
      return unless value?
      unless @path? and typeof @path.tag is 'string'
        throw new Error "leafref must contain 'path' statement"
      xpath = @path.tag
      # return a computed function (runs during get)
      func = ->
        res = @get xpath
        valid = switch
          when res instanceof Array then value in res
          else res is value
        unless valid is true
          err = new Error "#{@name} leafref is invalid for '#{value}' (not found in #{xpath})"
          err['error-tag'] = 'data-missing'
          err['error-app-tag'] = 'instance-required'
          err['err-path'] = xpath
          err
        else
          value
      func.computed = true
      return func

  new Typedef 'number',
    construct: (value) ->
      return unless value?
      if Number.isNaN (Number value)
        throw new Error "#{@tag} expects '#{value}' to convert into a number"
      if @range?
        ranges = @range.tag.split '|'
        ranges = ranges.map (e) ->
          [ min, max ] = e.split '..'
          if max is 'max'
            console.warn "max keyword on range not yet supported"
          min = (Number) min
          max = (Number) max
          (v) -> (not min? or v >= min) and (not max? or v <= max)
      value = Number value
      unless (not ranges? or ranges.some (test) -> test? value)
        throw new Error "#{@tag} range violation for '#{value}' on #{@range.tag}"
      value

  new Typedef 'string',
    construct: (value) ->
      return unless value?
      patterns = @pattern?.map (x) -> x.tag
      if @length?
        ranges = @length.tag.split '|'
        ranges = ranges.map (e) ->
          [ min, max ] = e.split '..'
          min = (Number) min
          max = switch
            when max is 'max' then null
            else (Number) max
          (v) -> (not min? or v.length >= min) and (not max? or v.length <= max)

      value = String value
      unless (not ranges? or ranges.some (test) -> test? value)
        throw new Error "#{@tag} length violation for '#{value}' on #{@length.tag}"
      unless (not patterns? or patterns.every (regex) -> regex.test value)
        throw new Error "#{@tag} pattern violation for '#{value}'"
      value

  new Typedef 'union',
    construct: (value) ->
      for type in @type
        try return type.convert value
        catch then continue
      throw new Error "#{@tag} unable to find matching type for '#{value}' within: #{@type}"
        
]
