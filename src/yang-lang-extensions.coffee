#
# YANG version 1.1 built-in language extensions
#

Expression = require './expression'
Extension  = require './extension'

Element = require './element'
XPath   = require './xpath'

module.exports = [

  new Extension 'action',
    data: true
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
    construct: (data={}) ->
      return data unless data instanceof Object
      rpc = data[@tag] ? @bindings[0] ? (a,b,c) => throw @error "handler function undefined"
      unless rpc instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless rpc.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      rpc = expr.eval rpc for expr in @expressions
      func = (args..., resolve, reject) ->
        # rpc expects only ONE argument
        rpc.apply this, [
          args[0],
          (res) -> resolve res
          (err) -> reject err
        ]
      func.async = true
      (new Element @tag, func, schema: this).update data
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Expression @tag, opts.key, this).bind data

  # TODO
  new Extension 'anydata',
    scope:
      config:       '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
  
  new Extension 'argument',
    argument: 'arg-type' # required
    scope:
      'yin-element': '0..1'

  new Extension 'augment',
    scope:
      action:        '0..n'
      anydata:       '0..n'
      anyxml:        '0..n'
      case:          '0..n'
      choice:        '0..n'
      container:     '0..n'
      description:   '0..1'
      'if-feature':  '0..n'
      leaf:          '0..n'
      'leaf-list':   '0..n'
      list:          '0..n'
      notification:  '0..n'
      reference:     '0..1'
      status:        '0..1'
      uses:          '0..n'
      when:          '0..1'
    resolve: -> @once 'created', =>
      target = switch @parent.kind
        when 'module'
          unless /^\//.test @tag
            throw @error "'#{@tag}' must be absolute-schema-path"
          @locate @tag
        when 'uses'
          if /^\//.test @tag
            throw @error "'#{@tag}' must be relative-schema-path"
          @parent.grouping.locate @tag

      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return
        
      unless @when?
        @debug? "augmenting '#{target.kind}:#{target.tag}'"
        target.extends @expressions.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        target.on 'eval', (data) =>
          data = expr.eval data for expr in @expressions if data?

  new Extension 'belongs-to',
    scope:
      prefix: '1'
    resolve: ->
      @module = @lookup 'module', @tag
      unless @module?
        throw @error "unable to resolve '#{@tag}' module"

  # TODO
  new Extension 'bit',
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'

  # TODO
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

  # TODO
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

  new Extension 'config',
    resolve: -> @tag = (@tag is true or @tag is 'true')
    construct: (data) ->
      return unless data?
      return data if @tag is true and data not instanceof Function
      
      unless data instanceof Function
        throw @error "cannot set data on read-only element"
        
      func = ->
        v = data.call this
        v = expr.eval v for expr in @schema.expressions when expr.kind isnt 'config'
        return v
      func.computed = true
      return func
    predicate: (data) -> not data? or @tag is true or data instanceof Function

  new Extension 'container',
    data: true
    scope:
      action:       '0..n'
      anydata:      '0..n'
      anyxml:       '0..n'
      choice:       '0..n'
      config:       '0..1'
      container:    '0..n'
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      must:         '0..n'
      notification: '0..n'
      presence:     '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      uses:         '0..n'
      when:         '0..1'
    construct: (data={}) -> 
      return data unless data instanceof Object
      obj = data[@tag] ? @bindings[0]
      obj = expr.eval obj for expr in @expressions if obj?
      (new Element @tag, obj, schema: this).update data
    predicate: (data) -> not data?[@tag]? or data[@tag] instanceof Object
    compose: (data, opts={}) ->
      return unless data?.constructor is Object
      # return unless typeof data is 'object' and Object.keys(data).length > 0
      # return if data instanceof Array
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug? "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, key: k
          break if match?
        return unless match?
        matches.push match

      (new Expression @tag, opts.key, this).extends matches...
      
  new Extension 'default',
    construct: (data) -> data ? @tag

  # TODO
  new Extension 'deviate',
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

  # TODO
  new Extension 'deviation',
    scope:
      description: '0..1'
      deviate:     '1..n'
      reference:   '0..1'

  new Extension 'enum',
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      value:       '0..1'
    resolve: -> 
      @parent.enumValue ?= 0
      unless @value?
        @extends "value #{@parent.enumValue++};"
      else
        cval = (Number @value.tag) + 1
        @parent.enumValue = cval unless @parent.enumValue > cval

  new Extension 'extension',
    argument: 'extension-name' # required
    scope: 
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    resolve: ->
      @origin = (@lookup 'extension', @tag)
      # this is a bit hackish...
      @compose = @origin?.compose?.bind @origin

  new Extension 'feature',
    scope:
      description:  '0..1'
      'if-feature': '0..n'
      reference:    '0..1'
      status:       '0..1'
      # TODO: augment scope with additional details
      # rpc:     '0..n'
      # feature: '0..n'
    resolve: ->
      if @status?.tag is 'unavailable'
        console.warn "feature #{@tag} is unavailable"
      # @on 'create', (element) =>
      #   element.state = require element.kw
      #   # if typeof ctx.feature is 'object'
      #   #   delete ctx.feature[tag]
      #   # else
      #   #   delete ctx.feature
    compose: (data, opts={}) ->
      return if data?.constructor is Object
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data.prototype).length is 0

      # TODO: expand on data with additional details...
      (new Expression @tag, opts.key ? data.name).bind data

  new Extension 'grouping',
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

  new Extension 'identity',
    scope:
      base:        '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    # TODO: resolve 'base' statements
    resolve: -> 
      if @base?
        @lookup 'identity', @base.tag

  new Extension 'if-feature',
    resolve: ->
      unless (@lookup 'feature', @tag)?
        console.warn "should be turned off..."
        #@define 'status', off

  new Extension 'import',
    scope:
      prefix: '1'
      'revision-date': '0..1'
    resolve: ->
      @module = @lookup 'module', @tag
      unless @module?
        throw @error "unable to resolve '#{@tag}' module"

      rev = @['revision-date']?.tag
      if rev? and not (@module.match 'revision', rev)?
        throw @error "requested #{rev} not available in #{@tag}"

      # TODO: Should be handled in extension construct
      # go through extensions from imported module and update 'scope'
      # for k, v of m.extension ? {}
      #   for pkey, scope of v.resolve 'parent-scope'
      #     target = @parent.resolve 'extension', pkey
      #     target?.scope["#{@prefix.tag}:#{k}"] = scope

  new Extension 'include',
    scope:
      argument: module
      'revision-date': '0..1'
    resolve: ->
      m = @lookup 'submodule', @tag
      unless m?
        throw @error "unable to resolve '#{@tag}' submodule"
      unless (@parent.tag is m['belongs-to'].tag)
        throw @error "requested submodule '#{@tag}' does not belongs-to '#{@parent.tag}'"
      @parent.extends m.expressions...

  new Extension 'input',
    data: true
    scope:
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      typedef:     '0..n'
      uses:        '0..n'
    construct: (func) ->
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      return (input, resolve, reject) ->
        # validate input prior to calling 'func'
        try input = expr.eval input for expr in @schema.input.expressions
        catch e then reject e
        func.call this, input, resolve, reject

  new Extension 'key',
    resolve: ->
      @tag = @tag.split ' '
      @once 'created', =>
        unless (@tag.every (k) => @parent.match('leaf', k)?)
          throw @error "referenced key items do not have leaf elements"
    construct: (data) ->
      return data unless data instanceof Array
      exists = {}
      for item in data when item instanceof Object
        key = (@tag.map (k) -> item[k]).join ','
        if exists[key] is true
          throw @error "key conflict for #{key}"
        exists[key] = true
        (new Element '@key', key, schema: this, enumerable: false).update item
        
        @debug? "defining a direct key mapping for '#{key}'"
        key = "__#{key}__" if (Number) key
        
        (new Element key, item, schema: this, enumerable: false).update data
      return data
    predicate: (data) ->
      return true if data instanceof Array
      @tag.every (k) => data[k]?

  new Extension 'leaf',
    data: true
    scope:
      config:       '0..1'
      default:      '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      type:         '0..1'
      units:        '0..1'
      when:         '0..1'
    resolve: -> 
      if @mandatory?.tag is true and @default?
        throw @error "cannot define 'default' when 'mandatory' is true"
    construct: (data={}) ->
      return data unless data?.constructor is Object
      val = data[@tag] ? @bindings[0]
      console.debug? "expr on leaf #{@tag} for #{val} with #{@expressions.length} exprs"
      val = expr.eval val for expr in @expressions
      (new Element @tag, val, schema: this).update data
    compose: (data, opts={}) ->
      return if data instanceof Array
      return if data instanceof Object and Object.keys(data).length > 0
      type = (@lookup 'extension', 'type')?.compose? data
      return unless type?
      @debug? "leaf #{opts.key} found #{type?.tag}"
      (new Expression @tag, opts.key, this).extends type

  new Extension 'leaf-list',
    data: true
    scope:
      config: '0..1'
      description: '0..1'
      'if-feature': '0..n'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must: '0..n'
      'ordered-by': '0..1'
      reference: '0..1'
      status: '0..1'
      type: '0..1'
      units: '0..1'
      when: '0..1'
    construct: (data={}) ->
      return data unless data instanceof Object
      ll = data[@tag] ? @bindings[0]
      ll = expr.eval ll for expr in @expressions if ll?
      (new Element @tag, ll, schema: this).update data
    predicate: (data) -> not data[@tag]? or data[@tag] instanceof Array
    compose: (data, opts={}) ->
      return unless data instanceof Array
      return unless data.every (x) -> typeof x isnt 'object'
      type_ = @lookup 'extension', 'type'
      types = data.map (x) -> type_.compose? x
      # TODO: form a type union if more than one types
      (new Expression @tag, opts.key, this).extends types[0]

  new Extension 'length',
    scope:
      description: '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference: '0..1'

  new Extension 'list',
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
      list = data[@tag] ? @bindings[0]
      if list instanceof Array
        list = list.map (li, idx) =>
          unless li instanceof Object
            throw @error "list item entry must be an object"
          li = expr.eval li for expr in @expressions
          li
      @debug? "processing list #{@tag} with #{@expressions.length}"
      list = expr.eval list for expr in @expressions if list?
      if list instanceof Array
        list.forEach (li, idx, self) => new Element idx, li, schema: this, parent: self
        Object.defineProperties list,
          add: value: (item...) ->
            # TODO: schema qualify the added items
            @push item...
          remove: value: (key) ->
            # TODO: optimize to break as soon as key is found
            @forEach (v, idx, arr) -> arr.slice idx, 1 if v['@key'] is key
      
      (new Element @tag, list, schema: this).update data
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

      (new Expression @tag, opts.key, this).extends matches...

  new Extension 'mandatory',
    resolve:   -> @tag = (@tag is true or @tag is 'true')
    predicate: (data) -> @tag isnt true or data?

  new Extension 'max-elements',
    resolve: -> @tag = (Number) @tag unless @tag is 'unbounded'
    predicate: (data) -> @tag is 'unbounded' or data not instanceof Array or data.length <= @tag

  new Extension 'min-elements',
    resolve: -> @tag = (Number) @tag
    predicate: (data) -> data not instanceof Array or data.length >= @tag 

  # TODO
  new Extension 'modifier',
    resolve: -> @tag = @tag is 'invert-match'

  new Extension 'module',
    argument: 'name' # required
    scope:
      anydata:      '0..n'
      anyxml:       '0..n'
      augment:      '0..n'
      choice:       '0..n'
      contact:      '0..1'
      container:    '0..n'
      description:  '0..1'
      deviation:    '0..n'
      extension:    '0..n'
      feature:      '0..n'
      grouping:     '0..n'
      identity:     '0..n'
      import:       '0..n'
      include:      '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      namespace:    '0..1'
      notification: '0..n'
      organization: '0..1'
      prefix:       '0..1'
      reference:    '0..1'
      revision:     '0..n'
      rpc:          '0..n'
      typedef:      '0..n'
      uses:         '0..n'
      'yang-version': '0..1'
    resolve: ->
      if @['yang-version']?.tag is '1.1'
        unless @namespace? and @prefix?
          throw @error "must define 'namespace' and 'prefix' for YANG 1.1 compliance"
      if @extension?.length > 0
        @debug? "found #{@extension.length} new extension(s)"
    construct: (data={}) ->
      return data unless data instanceof Object
      data = expr.eval data for expr in @expressions
      new Element @tag, data, schema: this
      return data
    compose: (data, opts={}) ->
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data).length is 0

      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug? "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, key: k
          break if match?
        unless match?
          console.log "unable to find match for #{k}"
          console.log v
        return unless match?
        matches.push match

      (new Expression @tag, opts.key, this).extends matches...

  # TODO
  new Extension 'must',
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  # TODO
  new Extension 'notification',
    scope:
      anydata:      '0..n'
      anyxml:       '0..n'
      choice:       '0..n'
      container:    '0..n'
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      uses:         '0..n'
    construct: -> 

  new Extension 'output',
    data: true
    scope:
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      typedef:     '0..n'
      uses:        '0..n'
    construct: (func) ->
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      return (input, resolve, reject) ->
        func.apply this, [
          input,
          (res) =>
            # validate output prior to calling 'resolve'
            try res = expr.eval res for expr in @schema.output.expressions
            catch e then reject e
            resolve res
          reject
        ]

  new Extension 'path',
    resolve: -> @tag = new XPath @tag

  new Extension 'pattern',
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      modifier:        '0..1'
      reference:       '0..1'
    resolve: -> @tag = new RegExp @tag

  new Extension 'prefix',
    resolve: -> # should validate prefix naming convention

  new Extension 'range',
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'refine',
    scope:
      default:        '0..1'
      description:    '0..1'
      reference:      '0..1'
      config:         '0..1'
      mandatory:      '0..1'
      presence:       '0..1'
      must:           '0..n'
      'min-elements': '0..1'
      'max-elements': '0..1'
      units:          '0..1'
    resolve: -> @parent.once 'created', =>
      target = @parent.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      # TODO: revisit this logic, may need to 'merge' the new expr into existing expr
      @expressions.forEach (expr) -> switch
        when target.hasOwnProperty expr.kind
          if expr.kind in [ 'must', 'if-feature' ] then target.extends expr
          else target[expr.kind] = expr
        else target.extends expr

  new Extension 'require-instance',
    resolve: -> @tag = (@tag is true or @tag is 'true')

  new Extension 'revision',
    scope:
      description: '0..1'
      reference:   '0..1'

  new Extension 'rpc',
    data: true
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
    construct: (data={}) ->
      return data unless data instanceof Object
      rpc = data[@tag] ? @bindings[0] ? (a,b,c) => throw @error "handler function undefined"
      unless rpc instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless rpc.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      rpc = expr.eval rpc for expr in @expressions
      func = (args..., resolve, reject) ->
        # rpc expects only ONE argument
        rpc.apply this, [
          args[0],
          (res) -> resolve res
          (err) -> reject err
        ]
      func.async = true
      (new Element @tag, func, schema: this).update data
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Expression @tag, opts.key, this).bind data

  new Extension 'submodule',
    scope:
      anyxml:         '0..n'
      augment:        '0..n'
      'belongs-to':   '0..1'
      choice:         '0..n'
      contact:        '0..1'
      container:      '0..n'
      description:    '0..1'
      deviation:      '0..n'
      extension:      '0..n'
      feature:        '0..n'
      grouping:       '0..n'
      identity:       '0..n'
      import:         '0..n'
      include:        '0..n'
      leaf:           '0..n'
      'leaf-list':    '0..n'
      list:           '0..n'
      notification:   '0..n'
      organization:   '0..1'
      reference:      '0..1'
      revision:       '0..n'
      rpc:            '0..n'
      typedef:        '0..n'
      uses:           '0..n'
      'yang-version': '0..1'
    resolve: ->
      # ctx.set 'submodule', @tag, this
      # ctx[k] = v for k, v of params
      # delete ctx.submodule

  new Extension 'status',
    resolve: -> @tag = @tag ? 'current'

  new Extension 'type',
    scope:
      base:               '0..1'
      bit:                '0..n'
      enum:               '0..n'
      'fraction-digits':  '0..1'
      length:             '0..1'
      path:               '0..1'
      pattern:            '0..n'
      range:              '0..1'
      'require-instance': '0..1'
      type:               '0..n' # for 'union' case only
    resolve: -> @once 'created', =>
      typedef = @lookup 'typedef', @tag
      unless typedef?
        throw @error "unable to resolve typedef for #{@tag}"
        
      @convert = typedef.convert?.bind null, this
      
      unless @parent.root or @parent.kind is 'type'
        try @parent.extends typedef.default, typedef.units
    construct: (data) -> switch
      when data instanceof Function then data
      when data instanceof Array then data.map (x) => @convert x
      else @convert data
    compose: (data, opts={}) ->
      return if data instanceof Function
      #return if data instanceof Object and Object.keys(data).length > 0
      typedefs = @lookup 'typedef'
      for typedef in typedefs
        @debug? "checking if '#{data}' is #{typedef.tag}"
        try break if (typedef.construct data) isnt undefined
        catch e then @debug? e
      return unless typedef? # shouldn't happen since almost everything is 'string'
      (new Expression @tag, typedef.tag)

  # TODO: address deviation from the conventional pattern
  new Extension 'typedef',
    scope:
      default:     '0..1'
      description: '0..1'
      units:       '0..1'
      type:        '0..1'
      reference:   '0..1'
    resolve: -> 
      if @type?
        @type.once 'created', => @convert = @type.convert
        return
      builtin = @lookup 'typedef', @tag
      unless builtin?.construct instanceof Function
        throw @error "unable to resolve '#{@tag}' built-in type"
      @convert = (schemas..., value) =>
        schema = schemas.reduce ((a,b) ->
          a[k] = v for own k, v of b; a
        ), {}
        builtin.construct.call schema, value

  new Extension 'unique',
    resolve: ->
      @tag = @tag = @tag.split ' '
      @once 'created', =>
        unless (@tag.every (k) => @parent.match('leaf', k)?)
          throw @error "referenced unique items do not have leaf elements"
    predicate: (data) ->
      return true unless data instanceof Array
      seen = {}
      data.every (item) =>
        key = @tag.reduce ((a,b) -> a += item[b] ), ''
        return false if seen[key]
        seen[key] = true
        return true
    
  new Extension 'uses',
    scope:
      augment:      '0..n'
      description:  '0..1'
      'if-feature': '0..n'
      refine:       '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
    resolve: -> @parent.once 'created', =>
      grouping = @lookup 'grouping', @tag
      unless grouping?
        throw @error "unable to resolve #{@tag} grouping definition"

      # setup change linkage to upstream definition
      #grouping.on 'extended', => @emit 'extended'
      @grouping = grouping.clone()
      unless @when?
        @debug? "extending #{@grouping} into #{@parent}"
        @parent.extends @grouping.expressions.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        @parent.on 'eval', (data) =>
          data = expr.eval data for expr in @grouping.expressions if data?

  # TODO
  new Extension 'when',
    scope:
      description: '0..1'
      reference:   '0..1'

  new Extension 'yin-element',
    argument: 'value' # required
]
