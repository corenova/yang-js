Typedef = require '../typedef'

module.exports =
  new Typedef 'enumeration',
    evaluate: (value) ->
      return unless value?
      unless @enum?.length > 0
        throw new Error "[#{@tag}] must have one or more 'enum' definitions"
      for i in @enum
        return i.tag if value is i.tag
        return i.tag if value is i.value.tag
        return i.tag if "#{value}" is i.value.tag
      throw new Error "[#{@tag}] type violation for '#{value}' on #{@enum.map (x) -> x.tag}"

