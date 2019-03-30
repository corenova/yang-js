debug = require('debug')('yang:store')
delegate = require('delegates')
Container = require('./container')

class Store extends Container
  constructor: ->
    unless this instanceof Store then return new Store arguments...
    super
    @state.schemas = new Set
    @state.models = new Map

  debug: -> debug @uri, arguments...

  delegate @prototype, 'state'
    .getter 'schemas'
    .getter 'models'

  delegate @prototype, 'models'
    .method 'has'

  @property 'store',
    get: -> this

  add: (schemas...) ->
    schemas
      .filter  (s) -> s.kind is 'module'
      .forEach (s) => @schemas.add(s)
    return this

  attach: (models...) ->
    models
      .filter  (m) -> m.kind is 'module'
      .forEach (m) =>
        m.on 'error', @emit.bind(this,'error')
        @models.set(m.name, m)
    return this

  access: (model) -> 
    unless @models.has(model)
      throw @error "unable to locate '#{model}' instance in the Store"
    return @models.get(model)

  set: (data) ->
    @models.clear()
    @schemas.forEach (s) => s.eval(data, this)
    return this

  find: (pattern, opts) ->
    i = @models.entries()
    while( v = i.next(); !v.done)
      [key, value] = v.value
      match = value.find(pattern, opts)
      return match if match.length
    return []

  toJSON: (tag = false, state = true) ->
    obj = {}
    i = @models.entries()
    while( v = i.next(); !v.done)
      [name, model] = v.value
      continue unless model?
      obj[k] = v for k, v of model.toJSON false, state
    return obj
    
module.exports = Store
