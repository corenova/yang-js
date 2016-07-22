Typedef = require '../typedef'

module.exports =
  # the 'integer' typedef is NOT part of RFC-6020 but this provides
  # generic integer type support
  new Typedef 'integer',
    evaluate: (value) ->
      return unless value?
      if (Number.isNaN (Number value)) or ((Number value) % 1) isnt 0
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      if typeof value is 'string' and !value
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      if @range?
        ranges = @range.tag.split '|'
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

