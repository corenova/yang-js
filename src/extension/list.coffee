Extension = require '../extension'
Yang      = require '../yang'
Property  = require '../property'

module.exports =
  new Extension 'list',
    argument: 'name'
    data: true
    scope:
      action:       '0..n' # v1.1
      anydata:      '0..n' # v1.1
      anyxml:       '0..n'
      choice:       '0..n'
      config:       '0..1'
      container:    '0..n'
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      key:          '0..1'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must:         '0..n'
      notification: '0..n'
      'ordered-by': '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      unique:       '0..1'
      uses:         '0..n'
      when:         '0..1'
      
    construct: (data={}) ->
      return data unless data instanceof Object
      list = data[@tag] ? @binding
      if list instanceof Array
        list = list.map (li, idx) =>
          unless li instanceof Object
            throw @error "list item entry must be an object"
          li = expr.eval li for expr in @elements
          li
      @debug? "processing list #{@tag} with #{@elements.length}"
      list = expr.eval list for expr in @elements if list?
      if list instanceof Array
        list.forEach (li, idx, self) => new Property idx, li, schema: this, parent: self
        Object.defineProperties list,
          add: value: (item...) ->
            # TODO: schema qualify the added items
            @push item...
          remove: value: (key) ->
            # TODO: optimize to break as soon as key is found
            @forEach (v, idx, arr) -> arr.slice idx, 1 if v['@key'] is key
      
      (new Property @tag, list, schema: this).update data
      
    predicate: (data) -> not data[@tag]? or data[@tag] instanceof Array
    
    compose: (data, opts={}) ->
      return unless data instanceof Array and data.length > 0
      return unless data.every (x) -> typeof x is 'object'

      # TODO: inspect more than first element
      data = data[0] 
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      for own k, v of data
        for expr in possibilities when expr?
          match = expr.compose? v, key: k
          break if match?
        return unless match?
        matches.push match

      (new Yang @tag, opts.key, this).extends matches...

