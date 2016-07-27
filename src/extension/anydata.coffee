Extension  = require '../extension'

module.exports =
  new Extension 'anydata',
    argument: 'name'
    scope:
      config:       '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
