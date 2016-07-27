Extension  = require '../extension'

module.exports =
  new Extension 'min-elements',
    argument: 'value'
    resolve: -> @tag = (Number) @tag
    predicate: (data) -> data not instanceof Array or data.length >= @tag 
