{ Typedef } = require('..')

generateRangeTest = (expr) ->
  [ min, max ] = expr.split /\s*\.\.\s*/
  min = (Number) min
  max = switch
    when max is 'max' then null
    else (Number) max
  (v) -> (not min? or v >= min) and (not max? or v <= max)

class Integer extends Typedef
  constructor: (name, range) ->
    source = 
      construct: (value, ctx, opts={}) ->
        if (Number.isNaN (Number value)) or ((Number value) % 1) isnt 0
          throw ctx.error "[#{@tag}] unable to convert '#{value}'"
        # treat '' string as undefined
        return if typeof value is 'string' and value is ''

        if opts.strict and typeof value isnt number
          throw ctx.error "[#{@tag}] must be a number but got #{typeof value}"

        value = Number value
        unless generateRangeTest(range)(value)
          throw ctx.error "[#{@tag}] range violation for '#{value}' on #{range}"
        
        ranges = @range?.tag.split '|'
        tests = ranges.map generateRangeTest if ranges? and ranges.length
        unless (not tests? or tests.some (test) -> test? value)
          throw ctx.error "[#{@tag}] custom range violation for '#{value}' on #{ranges}"
        value
    super name, source

module.exports = [

  new Typedef 'bits',
    construct: (value, ctx) ->
      unless @bit?.length > 0
        throw ctx.error "[#{@tag}] must have one or more 'bit' definitions"
      return unless value? and typeof value is 'string'
      # TODO: handle value a number in the future
      value = value.split ' '
      unless (value.every (v) -> @bit.some (b) -> b.tag is v)
        throw ctx.error "[#{@tag}] invalid bit name(s) for '#{value}' on #{@bit.map (x) -> x.tag}"
      value
  
  new Typedef 'boolean',
    construct: (value, ctx) ->
      switch
        when typeof value is 'string' 
          unless value in [ 'true', 'false' ]
            throw ctx.error "[#{@tag}] #{value} must be 'true' or 'false'"
          value is 'true'
        when typeof value is 'boolean' then value
        else throw ctx.error "[#{@tag}] unable to convert '#{value}'"

  new Typedef 'empty',
    construct: (value, ctx) ->
      @debug "convert"
      @debug value
      unless value is null
        throw ctx.error "[#{@tag}] cannot contain value other than null"
      null

  new Typedef 'binary',
    construct: (value, ctx) ->
      unless value instanceof Buffer
        throw ctx.error "[#{@tag}] unable to convert '#{value}'"
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
    construct: (value, ctx) ->
      if Number.isNaN (Number value)
        throw ctx.error "[#{@tag}] unable to convert '#{value}'"
      # treat '' string as undefined
      return if typeof value is 'string' and value is ''

      fixed = @['fraction-digits']?.tag or 1
      value = Number Number(value).toFixed(fixed)
      ranges = @range?.tag.split '|'
      tests = ranges.map generateRangeTest if ranges? and ranges.length
      unless (not tests? or tests.some (test) -> test? value)
        throw ctx.error "[#{@tag}] custom range violation for '#{value}' on #{ranges}"
      value

  new Typedef 'string',
    construct: (value, ctx, opts={}) ->
      patterns = @pattern?.map (x) -> x.tag
      lengths  = @length?.tag.split '|'
      tests = lengths?.map (e) ->
        [ min, max ] = e.split /\s*\.\.\s*/
        min = (Number) min
        max = switch
          when not max? then min
          when max is 'max' then null
          else (Number) max
        (v) -> (not min? or v.length >= min) and (not max? or v.length <= max)

      return if value is null
  
      type = typeof value
      if opts.strict and type isnt 'string'
        throw ctx.error "[#{@tag}] must be a string but got #{type}"
      value = String value
      if type is 'object' and /^\[object/.test value
        throw ctx.error "[#{@tag}] unable to convert '#{value}' into string"
      unless (not tests? or tests.some (test) -> test? value)
        throw ctx.error "[#{@tag}] length violation for '#{value}' on #{lengths}"
      unless (not patterns? or patterns.every (regex) -> regex.test value)
        throw ctx.error "[#{@tag}] pattern violation for '#{value}'"
      value

  new Typedef 'union',
    construct: (value, ctx) ->
      unless @type?
        throw ctx.error "[#{@tag}] must contain one or more type definitions"
      for type in @type
        try return type.convert value
        catch then continue
      throw ctx.error "[#{@tag}] unable to find matching type for '#{value}' within: #{@type}"
      
  new Typedef 'enumeration',
    construct: (value, ctx) ->
      unless @enum?.length > 0
        throw ctx.error "[#{@tag}] must have one or more 'enum' definitions"
      for i in @enum
        return i.tag if value is i.tag
        return i.tag if value is i.value.tag
        return i.tag if "#{value}" is i.value.tag
      throw ctx.error "[#{@tag}] type violation for '#{value}' on #{@enum.map (x) -> x.tag}"

  # TODO
  new Typedef 'identityref',
    construct: (value, ctx) ->
      unless @base? and typeof @base.tag is 'string'
        throw ctx.error "[#{@tag}] must reference 'base' identity"

      return value # BYPASS FOR NOW
        
      match = @lookup 'identity', value
      unless match?
        imports = (@lookup 'import') ? []
        for dep in imports
          match = dep.module.lookup 'identity', value
          break if match?
        unless match?
          modules = @lookup 'module'
          @debug "fallback searching all modules #{modules.map (x) -> x.tag}"
          for m in modules
            match = m.lookup 'identity', value
            break if match?
      match = match.base.state.identity if match?.base?
      @debug "base: #{@base} match: #{match} value: #{value}"
      # TODO - need to figure out how to return namespace value...
      unless (match? and @base.state.identity is match)
        throw ctx.error "[#{@tag}] identityref is invalid for '#{value}'"
      value

  new Typedef 'instance-identifier',
    construct: (value, ctx) ->
      @debug "processing instance-identifier with #{value}"
      try
        prop = ctx.in value
        throw ctx.error "missing schema element, identifier is invalid" unless prop?
        if @['require-instance']?.tag and not prop.active
          throw ctx.error "missing instance data"
      catch e
        err = new Error "[#{@tag}] #{ctx.name} is invalid for '#{value}' (not found in #{value})"
        err['error-tag'] = 'data-missing'
        err['error-app-tag'] = 'instance-required'
        err['err-path'] = value
        err.toString = -> value
        throw ctx.error err if ctx.attached
        return err
      value

  new Typedef 'leafref',
    construct: (value, ctx) ->
      unless @path?
        throw new Error "[#{@tag}] must contain 'path' statement"
        
      return value if @['require-instance']?.tag is false

      @debug "processing leafref with #{@path.tag}"
      res = ctx.get @path.tag
      @debug "got back #{res}"
      valid = switch
        when res instanceof Array then res.some (x) -> "#{x}" is "#{value}"
        else "#{res}" is "#{value}"
      unless valid is true
        @debug "invalid leafref '#{value}' detected for #{@path.tag}"
        @debug ctx.state
        err = new Error "[#{@tag}] #{ctx.name} is invalid for '#{value}' (not found in #{@path.tag})"
        err['error-tag'] = 'data-missing'
        err['error-app-tag'] = 'instance-required'
        err['err-path'] = @path.tag
        err.toString = -> value
        throw ctx.error err if ctx.attached
        return err
      value
]
