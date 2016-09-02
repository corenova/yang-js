Yang = require('./main').register()
url = require 'url'

module.exports = require('../schema/yang-store.yang').bind {

  store: -> @content ?= {}; return @content
  
  data: ->
    modules = @find('../store/*')
    modules.reduce ((a,b) -> a[k] = v for k, v of b.valueOf(); a), {}

  import: (input, resolve, reject) ->
    dataroot = @get '../data'
    model = switch
      when typeof input is 'string'    then Yang.parse(input).eval dataroot
      when input instanceof Yang       then input.eval dataroot
      when input instanceof Yang.Model then input
      #else Yang.compose(input).eval input

    console.info "importing '#{model.name}' to the store"
    model.join @get('../store')
    @emit 'import', model
    resolve
      name: model.name
      properties: model.props.map (x) -> x.name

  connect: (input, resolve, reject) ->
    to = url.parse input
    unless to.protocol?
      try data = require to.path
      catch then return reject "unable to fetch '#{to.path}' from local filesystem"
      @find('/data/*').forEach (prop) -> prop.merge data
      return resolve input
      
    client = @find("/#{to.protocol}client")
    unless client?
      throw new Error "unable to locate '/#{to.protocol}client' in the Store"
    client.connect to
    .then (data) =>
      prop.merge data for prop in @in('/')
      return data
    
}
