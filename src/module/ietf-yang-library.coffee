require 'yang-js'
crypto = require('crypto')
module.exports = require('../../schema/ietf-yang-library@2016-06-21.yang').bind {

  '/modules-state': ->
    modules = for module in @schema.constructor.module
      { revision, namespace, feature, include } = module
      name: module.tag
      revision:  revision?[0].tag ? ''
      namespace: namespace?.tag
      feature:   feature?.map (x) -> x.tag
      'conformance-type': 'implement'
      submodule: include?.map (x) ->
        name:     x.tag
        revision: x['revision-date']?.tag ? ''
    keys = modules.map (x) -> x.name
    hash = crypto.createHash('md5').update(keys.join(',')).digest('hex')
    return unless hash?
    prev = @content?['module-set-id']
    unless hash is prev
      # TODO: notification yang-library-change
      console.info "trigger yang-library-change notification"
    @content = 
      'module-set-id': hash
      module: modules
      
}
