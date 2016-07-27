Extension  = require '../extension'

module.exports =
  # TODO
  new Extension 'deviate',
    argument: 'value'
    scope:
      config:         '0..1'
      default:        '0..1'
      mandatory:      '0..1'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must:           '0..n'
      type:           '0..1'
      unique:         '0..1'
      units:          '0..1'
