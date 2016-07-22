Extension  = require '../extension'

# TODO
module.exports =
  new Extension 'choice',
    scope:
      anyxml:       '0..n'
      case:         '0..n'
      config:       '0..1'
      container:    '0..n'
      default:      '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      mandatory:    '0..1'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
