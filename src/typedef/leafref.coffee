Typedef = require '../typedef'

module.exports =
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
          err['err-path'] = xpath
          err
        else
          value
      func.computed = true
      return func
