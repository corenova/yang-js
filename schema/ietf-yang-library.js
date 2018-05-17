'use strict'

const Yang = require('..')
const Schema = require('./ietf-yang-library@2016-06-21.yang')
const crypto = require('crypto')

module.exports = Schema.bind({

  '/yanglib:modules-state': function() {
    let modules = Yang.module.map(module => {
      const { namespace, revision=[], feature=[], include=[] } = module
      return {
        name: module.tag,
        namespace: (namespace ? namespace.tag : ''),
        revision:  (revision[0] ? revision[0].tag : ''),
        feature:   feature.map(x => x.tag),
        'conformance-type': 'implement',
        submodule: include.map(x => ({
          name: x.tag,
          revision: x['revision-date'] ? x['revision-date'].tag : ''
        }))
      }
    })
    let keys = modules.map(x => x.name)
    let hash = crypto.createHash('md5').update(keys.join(',')).digest('hex')
    if (!hash) return this.content
    let prev = this.content ? this.content['module-set-id'] : undefined
    if (hash !== prev)
      // TODO: notification yang-library-change
      this.debug("trigger yang-library-change notification", keys)
    this.content = {
      'module-set-id': hash,
      module: modules
    }
    return this.content
  }

})
