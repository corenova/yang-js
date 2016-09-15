Yang   = require('../main')
crypto = require('crypto')

module.exports = require('../../schema/ietf-yang-library@2016-06-21.yang').bind {

  '/modules-state': ->
    modules = for module in Yang.module
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
    prev = @content?['module-set-id']
    unless hash is prev
      console.info "trigger yang-library-change notification"
    
    return {
      'module-set-id': hash
      module: modules
    }

  # TODO: notification yang-library-change
        
}
