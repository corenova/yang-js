Yang  = require '../yang'
Model = require '../model'
XPath = require '../xpath'
Extension = require '../extension'

module.exports = [

  new Extension 'action',
    argument: 'name'
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
    predicate: (data=->) -> data instanceof Function
    transform: (data) ->
      data ?= @binding ? -> throw @error "missing function binding"
      unless data instanceof Function
        @debug data
        # TODO: allow data to be a 'string' compiled into a Function?
        throw @error "expected a function but got a '#{typeof data}'"
      data = expr.eval data for expr in @exprs
      return data
    construct: (data={}) -> (new Model.Property @tag, this).join(data)
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Yang @tag, opts.tag, this).bind data

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

  new Extension 'argument',
    argument: 'arg-type'
    scope:
      'yin-element': '0..1'

  new Extension 'augment',
    argument: 'target-node'
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
    resolve: ->
      target = switch @parent.kind
        when 'module'
          unless /^\//.test @tag
            throw @error "'#{@tag}' must be absolute-schema-path"
          @locate @tag
        when 'uses'
          if /^\//.test @tag
            throw @error "'#{@tag}' must be relative-schema-path"
          @parent.state.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return
      unless @when?
        @debug "augmenting '#{target.kind}:#{target.tag}'"
        target.extends @exprs.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        target.on 'apply:after', (data) =>
          data = expr.apply data for expr in @exprs if data?

  new Extension 'base', argument: 'name'

  new Extension 'belongs-to',
    argument: 'module-name'
    scope:
      prefix: '1'
    resolve: ->
      @module = @lookup 'module', @tag
      unless @module?
        throw @error "unable to resolve '#{@tag}' module"

  new Extension 'bit',
    argument: 'name'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'

  new Extension 'case',
    argument: 'name'
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

  new Extension 'choice',
    argument: 'condition'
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
    argument: 'value'
    resolve: -> @tag = (@tag is true or @tag is 'true')

  new Extension 'contact', argument: 'text', yin: true

  new Extension 'container',
    argument: 'name'
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

    predicate: (data={}) -> data instanceof Object
    construct: (data={}, ctx) ->
      (new Model.Property @datakey, this).join(data, ctx?.state)
    compose: (data, opts={}) ->
      return unless data?.constructor is Object
      # return unless typeof data is 'object' and Object.keys(data).length > 0
      # return if data instanceof Array
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, tag: k
          break if match?
        return unless match?
        matches.push match

      (new Yang @tag, opts.tag, this).extends matches...

  new Extension 'default',
    argument: 'value'
    transform: (data) -> data ? @tag

  new Extension 'description', argument: 'text', yin: true

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

  # TODO
  new Extension 'deviation',
    argument: 'target-node'
    scope:
      description: '0..1'
      deviate:     '1..n'
      reference:   '0..1'

  new Extension 'enum',
    argument: 'name'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      value:       '0..1'
    resolve: ->
      @parent.enumValue ?= 0
      unless @value?
        @extends @constructor.parse "value #{@parent.enumValue++};"
      else
        cval = (Number @value.tag) + 1
        @parent.enumValue = cval unless @parent.enumValue > cval

  new Extension 'error-app-tag',
    argument: 'value' # required

  new Extension 'error-message',
    argument: 'value' # required
    yin: true

  new Extension 'extension',
    argument: 'extension-name'
    scope:
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'

  new Extension 'feature',
    argument: 'name'
    scope:
      description:  '0..1'
      'if-feature': '0..n'
      reference:    '0..1'
      status:       '0..1'
    construct: (data, ctx) ->
      feature = @binding
      feature = expr.eval feature for expr in @exprs
      (new Model.Property @tag, this).join(ctx.engine) if feature?
      return data
    compose: (data, opts={}) ->
      return if data?.constructor is Object
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data.prototype).length is 0

      # TODO: expand on data with additional details...
      (new Yang @tag, opts.tag ? data.name).bind data

  new Extension 'fraction-digits',
    argument: 'value' # required

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
    transform: (data) -> data

  new Extension 'identity',
    argument: 'name'
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
    argument: 'feature-name'
    transform: (data) ->
      feature = @lookup 'feature', @tag
      return data if feature?.binding?

  new Extension 'import',
    argument: 'module'
    scope:
      prefix: '1'
      'revision-date': '0..1'
    resolve: ->
      module = @lookup 'module', @tag
      unless module?
        throw @error "unable to resolve '#{@tag}' module"

      # defined as non-enumerable
      Object.defineProperty this, 'module', value: module

      rev = @['revision-date']?.tag
      if rev? and not (@module.match 'revision', rev)?
        throw @error "requested #{rev} not available in #{@tag}"
      # TODO: Should be handled in extension construct
      # go through extensions from imported module and update 'scope'
      # for k, v of m.extension ? {}
      #   for pkey, scope of v.resolve 'parent-scope'
      #     target = @parent.resolve 'extension', pkey
      #     target?.scope["#{@prefix.tag}:#{k}"] = scope
    transform: (data) ->
      # below is a very special transform
      unless @module.tag of Model.Store
        @debug "IMPORT: absorbing data for '#{@tag}'"
        @module.eval(data) 
      delete data[k] for own k of data when @module.locate(k)?
      return data

  new Extension 'include',
    argument: 'module'
    scope:
      'revision-date': '0..1'
    resolve: ->
      m = @lookup 'submodule', @tag
      unless m?
        throw @error "unable to resolve '#{@tag}' submodule"
      unless @parent.tag is m['belongs-to'].tag
        throw m.error "requested submodule '#{@tag}' not belongs-to '#{@parent.tag}'"

      m['belongs-to'].module = @parent
      for x in m.elements when m.scope[x.kind] is '0..n' and x.kind isnt 'revision'
        (@parent.update x).compile()

  new Extension 'input',
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
    construct: (data={}) -> (new Model.Property @kind, this).join(data)
      
  new Extension 'key',
    argument: 'value'
    resolve: -> @parent.once 'compile:after', =>
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "unable to reference key items as leaf elements", @parent
    transform: (data) ->
      return data unless data instanceof Object
      switch
        when data instanceof Array
          exists = {}
          data.forEach (item) =>
            return unless item instanceof Object
            key = item['@key']
            throw @error "key conflict for #{key}" if exists[key]
            exists[key] = true
        when not data.hasOwnProperty '@key'
          Object.defineProperty data, '@key',
            get: (-> (@tag.map (k) -> data[k]).join ',' ).bind this
      return data
    predicate: (data) ->
      return true unless data instanceof Object
      return true if data instanceof Array
      @tag.every (k) -> data.hasOwnProperty k

  new Extension 'leaf',
    argument: 'name'
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
      if @mandatory?.tag is 'true' and @default?
        throw @error "cannot define 'default' when 'mandatory' is true"
    predicate: (data) -> data not instanceof Object or data instanceof Promise
    transform: (data, ctx) ->
      data = expr.eval data, ctx for expr in @exprs when expr.kind isnt 'type'
      return data unless @type?
      try @type.apply data, ctx
      catch err
        throw err unless ctx.state.suppress
        ctx.defer(data)
    construct: (data={}, ctx) ->
      (new Model.Property @datakey, this).join(data, ctx?.state)
    compose: (data, opts={}) ->
      return if data instanceof Array
      return if data instanceof Object and Object.keys(data).length > 0
      type = (@lookup 'extension', 'type')?.compose? data
      return unless type?
      @debug "leaf #{opts.tag} found #{type?.tag}"
      (new Yang @tag, opts.tag, this).extends type

  new Extension 'leaf-list',
    argument: 'name'
    scope:
      config:         '0..1'
      description:    '0..1'
      'if-feature':   '0..n'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must:           '0..n'
      'ordered-by':   '0..1'
      reference:      '0..1'
      status:         '0..1'
      type:           '0..1'
      units:          '0..1'
      when:           '0..1'

    predicate: (data=[]) -> data instanceof Array and data.every (x) -> typeof x isnt 'object'
    transform: (data, ctx) ->
      unless data instanceof Array
        data = []
        data = expr.eval data, ctx for expr in @exprs when data?
        return
      data = data.filter(Boolean)
      output = {}
      output[data[key]] = data[key] for key in [0...data.length]
      data = (value for key, value of output)
      data = expr.eval data, ctx for expr in @exprs when expr.kind isnt 'type'
      return data unless @type?
      try @type.apply data, ctx
      catch err
        throw err unless ctx.state.suppress
        ctx.defer(data)
    construct: (data={}, ctx) ->
      (new Model.Property @datakey, this).join(data, ctx?.state)
    compose: (data, opts={}) ->
      return unless data instanceof Array
      return unless data.every (x) -> typeof x isnt 'object'
      type_ = @lookup 'extension', 'type'
      types = data.map (x) -> type_.compose? x
      # TODO: form a type union if more than one types
      (new Yang @tag, opts.tag, this).extends types[0]

  new Extension 'length',
    argument: 'value'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'list',
    argument: 'name'
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

    predicate: (data={}) -> data instanceof Object
    transform: (data, ctx) ->
      if data instanceof Array
        data.forEach (item, idx) =>
          (new Model.Property idx, this).join(data, ctx.state)
        data = attr.eval data, ctx for attr in @attrs
      else
        data = expr.eval data, ctx for expr in @exprs when data?
      return data
    construct: (data={}, ctx) ->
      (new Model.Property @datakey, this).join(data, ctx.state)
    compose: (data, opts={}) ->
      return unless data instanceof Array and data.length > 0
      return unless data.every (x) -> typeof x is 'object'

      # TODO: inspect more than first element
      data = data[0]
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      for own k, v of data
        for expr in possibilities when expr?
          match = expr.compose? v, tag: k
          break if match?
        return unless match?
        matches.push match

      (new Yang @tag, opts.tag, this).extends matches...

  new Extension 'mandatory',
    argument: 'value'
    resolve:   -> @tag = (@tag is true or @tag is 'true')
    predicate: (data) -> @tag isnt true or data? or @parent.binding?

  new Extension 'max-elements',
    argument: 'value'
    resolve: -> @tag = (Number) @tag unless @tag is 'unbounded'
    predicate: (data) -> @tag is 'unbounded' or data not instanceof Array or data.length <= @tag

  new Extension 'min-elements',
    argument: 'value'
    resolve: -> @tag = (Number) @tag
    predicate: (data) -> data not instanceof Array or data.length >= @tag

  # TODO
  new Extension 'modifier',
    argument: 'value'
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
        @debug "found #{@extension.length} new extension(s)"
    construct: (data={}) -> (new Model @tag, this).set(data)
    compose: (data, opts={}) ->
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data).length is 0

      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, tag: k
          break if match?
        unless match?
          @debug "unable to find match for #{k}"
          @debug v
        return unless match?
        matches.push match

      (new Yang @tag, opts.tag, this).extends matches...

  # TODO
  new Extension 'must',
    argument: 'condition'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'namespace',
    argument: 'uri' # required

  # TODO
  new Extension 'notification',
    argument: 'event'
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
    transform: (data) -> data

  new Extension 'ordered-by',
    argument: 'value' # required

  new Extension 'organization',
    argument: 'text' # required
    yin: true

  new Extension 'output',
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
    construct: (data={}) -> (new Model.Property @kind, this).join(data)

  new Extension 'path',
    argument: 'value'
    resolve: -> @root.once 'compile:after', =>
      @tag = new XPath @tag, @parent?.parent

  new Extension 'pattern',
    argument: 'value'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      modifier:        '0..1'
      reference:       '0..1'
    resolve: -> @tag = new RegExp @tag

  new Extension 'position',
    argument: 'value' # required

  new Extension 'prefix',
    argument: 'value'
    resolve: -> # should validate prefix naming convention

  new Extension 'presence',
    argument: 'value' # required

  new Extension 'range',
    argument: 'value'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'reference',
    argument: 'value' # required

  new Extension 'refine',
    argument: 'target-node'
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

    resolve: ->
      target = @parent.state.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      @debug "APPLY #{this} to #{target}"
      # TODO: revisit this logic, may need to 'merge' the new expr into existing expr
      @exprs.forEach (expr) -> switch
        when target.hasOwnProperty expr.kind
          if expr.kind in [ 'must', 'if-feature' ] then target.extends expr
          else target[expr.kind] = expr
        else target.extends expr

  new Extension 'require-instance',
    argument: 'value'
    resolve: -> @tag = (@tag is true or @tag is 'true')

  new Extension 'revision',
    argument: 'date'
    scope:
      description: '0..1'
      reference:   '0..1'

  new Extension 'revision-date',
    argument: 'date'

  new Extension 'rpc',
    argument: 'name'
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'

    predicate: (data=->) -> data instanceof Function
    transform: (data) ->
      data ?= @binding ? -> throw new Error "missing function binding for #{@path}"
      unless data instanceof Function
        @debug data
        # TODO: allow data to be a 'string' compiled into a Function?
        throw @error "expected a function but got a '#{typeof data}'"
      data = expr.eval data for expr in @exprs
      return data
    construct: (data={}) -> (new Model.Property @datakey, this).join(data)
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Yang @tag, opts.tag, this).bind data

  new Extension 'status',
    argument: 'value'
    resolve: -> @tag = @tag ? 'current'

  new Extension 'submodule',
    argument: 'name'
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

  new Extension 'type',
    argument: 'name'
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

    resolve: ->
      typedef = @lookup 'typedef', @tag
      unless typedef?
        @debug @parent
        throw @error "unable to resolve typedef for #{@tag}"
      if typedef.type?
        @update expr for expr in typedef.type.exprs
        @primitive = typedef.type.primitive
      else
        @primitive = @tag
      convert = typedef.convert
      unless convert?
        convert = typedef.compile().convert
        unless convert?
          throw @error "no convert found for #{typedef.tag}"
      @convert = convert.bind this
      if @parent? and @parent.kind isnt 'type'
        try @parent.extends typedef.default, typedef.units
    transform: (data, ctx) -> switch
      when data instanceof Function then data
      when data instanceof Array    then data.map (x) => @convert x, ctx
      when data instanceof Object   then data
      else @convert data, ctx
    compose: (data, opts={}) ->
      return if data instanceof Function
      #return if data instanceof Object and Object.keys(data).length > 0
      typedefs = @lookup 'typedef'
      for typedef in typedefs
        @debug "checking if '#{data}' is #{typedef.tag}"
        try break if (typedef.convert data) isnt undefined
        catch e then @debug e
      return unless typedef? # shouldn't happen since almost everything is 'string'
      (new Yang @tag, typedef.tag)

  # TODO: address deviation from the conventional pattern
  new Extension 'typedef',
    argument: 'name'
    scope:
      default:     '0..1'
      description: '0..1'
      units:       '0..1'
      type:        '0..1'
      reference:   '0..1'
      status:      '0..1'

    resolve: ->
      if @type?
        @convert = @type.compile().convert
        return
      builtin = @lookup 'typedef', @tag
      unless builtin?
        throw @error "unable to resolve '#{@tag}' built-in type"
      @convert = builtin.convert

  new Extension 'unique',
    argument: 'tag'
    resolve: ->
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "referenced unique items do not have leaf elements"
    predicate: (data) ->
      return true unless data instanceof Array
      seen = {}
      data.every (item) =>
        return true unless @tag.every (k) -> item[k]?
        key = @tag.reduce ((a,b) -> a += item[b]), ''
        return false if seen[key]
        seen[key] = true
        return true

  new Extension 'units',
    argument: 'value'

  new Extension 'uses',
    argument: 'grouping-name'
    scope:
      augment:      '0..n'
      description:  '0..1'
      'if-feature': '0..n'
      refine:       '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'

    resolve: ->
      grouping = @lookup 'grouping', @tag
      unless grouping?
        throw @error "unable to resolve #{@tag} grouping definition"

      # setup change linkage to upstream definition
      #grouping.on 'changed', => @emit 'changed'

      ref = @state.grouping = grouping.clone()
      # NOTE: declared as non-enumerable
      #Object.defineProperty this, 'grouping', value: 
      unless @when?
        @debug "extending with #{ref.elements.length} elements"
        @parent.extends ref.elements.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        @parent.on 'apply:after', (data) =>
          data = expr.apply data for expr in ref.exprs if data?
    transform: (data) -> @debug Object.keys(data); data

  new Extension 'value',
    argument: 'value' # required

  # TODO
  new Extension 'when',
    argument: 'condition'
    scope:
      description: '0..1'
      reference:   '0..1'

  new Extension 'yang-version',
    argument: 'value' # required

  new Extension 'yin-element',
    argument: 'value' # required

]
