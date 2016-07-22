Extension = require '../extension'
XPath     = require '../xpath'

module.exports =
  new Extension 'path',
    resolve: -> @tag = new XPath @tag

