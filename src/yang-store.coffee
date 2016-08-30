Yang = require('./main').register()

module.exports = require('../schema/yang-store.yang').bind {

  import: (input, resolve, reject) ->
    dataroot = @find '/data'
    model = switch
      when typeof input is 'string'    then Yang.parse(input).eval()
      when input instanceof Yang.Model then input
      when input instanceof Yang       then input.eval()
      else Yang.compose(input).eval()

    propNames = []
    for prop in model.at('/')
      console.info "[#{@name}] importing '#{prop.name}' from model to the store"
      do (prop) ->
        Object.defineProperty model, prop.name, get: (-> @[prop.name] ).bind dataroot
        prop.join dataroot
      propNames.push prop.name
      
    @emit 'import', model
    resolve properties: propNames
}
