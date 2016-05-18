# element - cascading element tree

class Element
  constructor: (schema) ->
    unless schema?
      throw @error "cannot create a new #{@constructor.name} without a valid schema"

    Object.defineProperty this, '__schema__', value: schema
    for k, prop of schema when prop instanceof Object and k isnt 'constructor'
      if prop instanceof Function
        do (prop) ->
          prop._value = undefined
          prop.get = -> prop._value.valueOf()
          prop.set = (newValue) ->
            console.log "setting newValue"
            console.log newValue
            prop._value = new prop newValue
      Object.defineProperty this, k, prop
    # unless schema.validate data
    #   throw @error "passed in data failed to validate schema"

module.exports = Element
