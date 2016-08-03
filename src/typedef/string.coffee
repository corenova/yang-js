Typedef = require '../typedef'

module.exports =
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
            when max is 'max' then null
            else (Number) max
          (v) -> (not min? or v.length >= min) and (not max? or v.length <= max)

      value = String value
      unless (not ranges? or ranges.some (test) -> test? value)
        throw new Error "[#{@tag}] length violation for '#{value}' on #{@length.tag}"
      unless (not patterns? or patterns.every (regex) -> regex.test value)
        throw new Error "[#{@tag}] pattern violation for '#{value}'"
      value

