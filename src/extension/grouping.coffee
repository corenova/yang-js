Extension  = require '../extension'

module.exports =
  new Extension 'grouping',
    argument: 'name'
    scope:
      action:      '0..n'
      anydata:     '0..n'
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      description: '0..1'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      notification:'0..n'
      reference:   '0..1'
      status:      '0..1'
      typedef:     '0..n'
      uses:        '0..n'

