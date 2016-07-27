Extension  = require '../extension'

module.exports =
  # TODO: address deviation from the conventional pattern
  new Extension 'typedef',
    argument: 'name'
    scope:
      default:     '0..1'
      description: '0..1'
      units:       '0..1'
      type:        '0..1'
      reference:   '0..1'
      
    resolve: -> 
      if @type?
        @convert = @type.resolve().convert
        return
        
      builtin = @lookup 'typedef', @tag
      unless builtin?
        throw @error "unable to resolve '#{@tag}' built-in type"
        
      @convert = (schemas..., value) =>
        schemas.unshift builtin.schema if builtin.schema?
        schema = schemas.reduce ((a,b) ->
          a[k] = v for own k, v of b; a
        ), {}
        builtin.convert.call schema, value
