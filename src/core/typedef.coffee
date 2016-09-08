Element = require './element'

class Typedef extends Element
  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    super 'typedef', name
    
    Object.defineProperties this,
      convert: value: spec.construct ? (x) -> x
      schema:  value: spec.schema

class Integer extends Typedef
  constructor: (name, range) ->
    super name,
      construct: (value) ->
        return unless value?
        if (Number.isNaN (Number value)) or ((Number value) % 1) isnt 0
          throw new Error "[#{@tag}] unable to convert '#{value}'"
        if typeof value is 'string' and !value
          throw new Error "[#{@tag}] unable to convert '#{value}'"

        range = @range.tag if @range?
        if range?
          ranges = range.split '|'
          ranges = ranges.map (e) ->
            [ min, max ] = e.split /\s*\.\.\s*/
            min = (Number) min
            max = switch
              when max is 'max' then null
              else (Number) max
            (v) -> (not min? or v >= min) and (not max? or v <= max)
        value = Number value
        unless (not ranges? or ranges.some (test) -> test? value)
          throw new Error "[#{@tag}] range violation for '#{value}' on #{@range.tag}"
        value

exports = module.exports = Typedef
exports.builtins = [
  
  new Typedef 'boolean',
    construct: (value) ->
      return unless value?
      switch
        when typeof value is 'string' 
          unless value in [ 'true', 'false' ]
            throw new Error "[#{@tag}] #{value} must be 'true' or 'false'"
          value is 'true'
        when typeof value is 'boolean' then value
        else throw new Error "[#{@tag}] unable to convert '#{value}'"

  new Typedef 'empty',
    construct: (value) ->
      if value?
        throw new Error "[#{@tag}] cannot contain value"
      null

  new Typedef 'binary',
    construct: (value) ->
      return unless value?
      unless value instanceof Object
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      value

  new Integer 'int8',   '-128..127'
  new Integer 'int16',  '-32768..32767'
  new Integer 'int32',  '-2147483648..2147483647'
  new Integer 'int64',  '-9223372036854775808..9223372036854775807'
  new Integer 'uint8',  '0..255'
  new Integer 'uint16', '0..65535'
  new Integer 'uint32', '0..4294967295'
  new Integer 'uint64', '0..18446744073709551615'

  new Typedef 'decimal64',
    construct: (value) ->
      return unless value?
      if Number.isNaN (Number value)
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      if typeof value is 'string' and !value
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      switch
        when typeof value is 'string' then Number value
        when typeof value is 'number' then value
        else throw new Error "[#{@tag}] type violation for #{value}"

  new Typedef 'string',
    construct: (value) ->
      return unless value?
      patterns = @pattern?.map (x) -> x.tag
      if @length?
        ranges = @length.tag.split '|'
        ranges = ranges.map (e) ->
          [ min, max ] = e.split /\s*\.\.\s*/
          min = (Number) min
          max = switch
            when not max? then min
            when max is 'max' then null
            else (Number) max
          (v) -> (not min? or v.length >= min) and (not max? or v.length <= max)

      value = String value
      unless (not ranges? or ranges.some (test) -> test? value)
        throw new Error "[#{@tag}] length violation for '#{value}' on #{@length.tag}"
      unless (not patterns? or patterns.every (regex) -> regex.test value)
        throw new Error "[#{@tag}] pattern violation for '#{value}'"
      value

  new Typedef 'union',
    construct: (value) ->
      unless @type?
        throw new Error "[#{@tag}] must contain one or more type definitions"
      for type in @type
        try return type.convert value
        catch then continue
      throw new Error "[#{@tag}] unable to find matching type for '#{value}' within: #{@type}"
      
  new Typedef 'enumeration',
    construct: (value) ->
      return unless value?
      unless @enum?.length > 0
        throw new Error "[#{@tag}] must have one or more 'enum' definitions"
      for i in @enum
        return i.tag if value is i.tag
        return i.tag if value is i.value.tag
        return i.tag if "#{value}" is i.value.tag
      throw new Error "[#{@tag}] type violation for '#{value}' on #{@enum.map (x) -> x.tag}"

  # TODO
  new Typedef 'identityref',
    construct: (value) ->
      return unless value?
      unless @base? and typeof @base.tag is 'string'
        throw new Error "[#{@tag}] must reference 'base' identity"
      base = @base.tag
      
      unless @base? and typeof @base.tag is 'string'
        throw new Error "[#{@tag}] must reference 'base' identity"

      return value # XXX - bypass verification for now
      
      # fix this later
      base = @base.tag
      match = origin.lookup 'identity', value
      unless match?
        imports = (origin.lookup 'import') ? []
        for m in imports
          match = m.module.lookup 'identity', value
          break if match? 

      console.debug? "base: #{base} match: #{match} value: #{value}"
      # TODO - need to figure out how to return namespace value...
      # unless (match? and base is match.base?.tag)
      #   throw new Error "[#{@tag}] identityref is invalid for '#{value}'"
      value

  # TODO
  new Typedef 'instance-identifier',
    construct: (value) ->
      return unless value?
      unless (typeof value is 'string') and /([^\/^\[]+(?:\[.+\])*)/.test value
        throw new Error "[#{@tag}] unable to convert #{value} into valid XPATH expression"
      value

  new Typedef 'leafref',
    construct: (value) ->
      return unless value?
      unless @path?
        throw new Error "[#{@tag}] must contain 'path' statement"
      xpath = @path.tag
      # return a computed function (runs during get)
      func = ->
        res = @get xpath
        valid = switch
          when res instanceof Array then value in res
          else res is value
        unless valid is true
          err = new Error "[#{@tag}] #{@name} is invalid for '#{value}' (not found in #{xpath})"
          err['error-tag'] = 'data-missing'
          err['error-app-tag'] = 'instance-required'
          err['err-path'] = "#{xpath}"
          err
        else
          value
      func.computed = true
      return func
      
]
