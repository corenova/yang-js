Typedef = require '../typedef'

class Integer extends Typedef
  constructor: (name, range) ->
    super name, schema: range: tag: range

  convert: (value) ->
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

module.exports = [
  new Integer 'int8',   '-128..127'
  new Integer 'int16',  '-32768..32767'
  new Integer 'int32',  '-2147483648..2147483647'
  new Integer 'int64',  '-9223372036854775808..9223372036854775807'
  new Integer 'uint8',  '0..255'
  new Integer 'uint16', '0..65535'
  new Integer 'uint32', '0..4294967295'
  new Integer 'uint64', '0..18446744073709551615'
]
