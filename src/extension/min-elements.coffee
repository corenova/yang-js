Extension  = require '../extension'

module.exports =
  new Extension 'min-elements',
    resolve: -> @tag = (Number) @tag
    predicate: (data) -> data not instanceof Array or data.length >= @tag 
