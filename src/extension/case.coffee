Extension  = require '../extension'

# TODO
module.exports =
  new Extension 'case',
    scope:
      anyxml:       '0..n'
      choice:       '0..n'
      container:    '0..n'
      description:  '0..1'
      'if-feature': '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      uses:         '0..n'
      when:         '0..1'
