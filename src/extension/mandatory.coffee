Extension  = require '../extension'

module.exports =
  new Extension 'mandatory',
    resolve:   -> @tag = (@tag is true or @tag is 'true')
    predicate: (data) -> @tag isnt true or data?

