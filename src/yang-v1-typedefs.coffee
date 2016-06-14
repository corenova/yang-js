#
# YANG version 1.0 built-in TYPEDEFs
#
Expression = require './expression'

module.exports = [

  new Expression 'binary',
    kind: 'typedef'
    construct: (value) ->
      return unless value?
      unless value instanceof Function
        throw @error "value not a binary instance", value
      value

  new Expression 'boolean',
    kind: 'typedef'
    construct: (value) ->
      return unless value?
      if typeof value is 'string' 
        unless value in [ 'true', 'false' ]
          throw new Error "boolean value must be 'true' or 'false'"
        value is 'true'
      else
        Boolean value

  new Expression 'decimal64',
    kind: 'typedef'
    construct: (value) ->
      return unless value?
      if Number.isNaN (Number value)
        throw new Error "#{@tag} unable to construct '#{value}'"
      Number value

  new Expression 'empty',
    kind: 'typedef'
    construct: (value) -> null

  new Expression 'enumeration',
    kind: 'typedef'
    construct: (value) ->
      return unless value?
      unless @enum?.length > 0
        trhow new Error "#{@tag} enumeration must have one or more 'enum' definitions"
      for i in @enum
        return i.tag if value is i.tag
        return i.tag if value is i.value.tag
        return i.tag if "#{value}" is i.value.tag
      throw new Error "#{@tag} enumeration type violation for '#{value}' on #{@enum.map (x) -> x.tag}"

  # TODO
  new Expression 'identityref',
    kind: 'typedef'
    construct: (value) ->
      unless typeof params.base is 'string'
        throw source.error "identityref must reference 'base' identity"

      (value) ->
        match = source.resolve 'identity', value
        unless (match? and params.base is match.base)
          throw source.error "[#{@opts.type}] identityref is invalid for '#{value}'"
        # TODO - need to figure out how to return namespace value...
        value

  # TODO
  new Expression 'instance-identifier',
    kind: 'typedef'
    construct: (value) ->

  new Expression 'leafref',
    kind: 'typedef'
    construct: (value) ->
      if value?
        throw @error "cannot config set value for leafref type"
      unless @path? and typeof @path.tag is 'string'
        throw @error "leafref must contain 'path' statement"
      xpath = @path.tag
      func = (->
        res = @get xpath
        # should verify it's a leaf
        return res
      )
      func.computed = true
      return func

  new Expression 'number',
    kind: 'typedef'
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

  new Expression 'string',
    kind: 'typedef'
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

  new Expression 'union',
    kind: 'typedef'
    construct: (value) ->
      for type in @type
        try return type.convert value
        catch then continue
      throw new Error "#{@tag} unable to find matching type for '#{value}' within: #{@type}"
        
]
