Extension = require '../extension'
XPath     = require '../xpath'

module.exports =
  new Extension 'path',
    argument: 'value'
    resolve: -> @tag = new XPath @tag

