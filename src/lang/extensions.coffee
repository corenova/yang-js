{ Yang, Extension, XPath, Model, Container, List, Method, Notification, Property } = require '..'

Arguments = require './arguments'

assert = require 'assert'

STRIP_COMMENTS = /(\/\/.*$)|(\/\*[\s\S]*?\*\/)|(\s*=[^,\)]*(('(?:\\'|[^'\r\n])*')|("(?:\\"|[^"\r\n])*"))|(\s*=[^,\)]*))/mg
ARGUMENT_NAMES = /([^\s,]+)/g

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
    predicate: (data=->) ->
      assert data instanceof Function,
        "data must contain a valid instanceof Function"
    resolve: ->
      @extends (new Yang 'input') unless @input
      @extends (new Yang 'output') unless @output
    transform: (data, ctx, opts) ->
      return unless data?
      unless data instanceof Function
        @debug => data
        # TODO: allow data to be a 'string' compiled into a Function?
        throw @error "expected a function but got a '#{typeof data}'"
      data = expr.eval data, ctx, opts for expr in @exprs
      return data
    construct: -> (new Method name: @tag, schema: this).attach arguments...
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless not data.prototype? or Object.keys(data.prototype).length is 0

      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      for expr in possibilities when expr?
        match = expr.compose? data
        matches.push match if match?
      (new Yang @tag, opts.tag, this).extends matches...

  new Extension 'anydata',
    argument: 'name'
    data: true
    scope:
      config:       '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
    construct: -> (new Property this).attach arguments...

  new Extension 'anyxml',
    argument: 'name'
    data: true
    scope:
      config:       '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
    construct: -> (new Property this).attach arguments...

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
            throw @error "'#{@tag}' must be absolute-schema-path to augment within module statement"
          @locate @tag
        else
          unless /^[_0-9a-zA-Z]/.test @tag
            throw @error "'#{@tag}' must be relative-schema-path to augment within uses statement"
          @parent.state.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return
        
      unless @when?
        @once 'compiled', =>
          @debug => "augmenting '#{target.kind}:#{target.tag}'"
          target.extends @nodes.map (x) => x.clone origin: this, relative: false
      else
        target.on 'transformed', (data) =>
          data = expr.apply data for expr in @exprs if data?
    transform: (data) -> data

  new Extension 'base',
    argument: 'name'
    resolve: ->
      ref = @state.identity = @lookup 'identity', @tag
      unless ref?
        throw @error "unable to resolve '#{@tag}' identity"

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
      'if-feature': '0..n' # YANG 1.1
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'
    resolve: ->
      @parent.bitPosition ?= 0
      unless @position?
        @extends @constructor.parse "position #{@parent.bitPosition++};"
      else
        cval = (Number @position.tag) + 1
        @parent.bitPosition = cval unless @parent.bitPosition > cval

  new Extension 'case',
    argument: 'name'
    scope:
      anydata:      '0..n'
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
    resolve: ->
      @once 'compiled', =>
        unless @nodes.length > 0
          throw @error "cannot have an empty case statement"
    transform: (data, ctx, opts) ->
      return data unless data instanceof Object
      keys = Object.keys data
      unless (@nodes.some (x) -> x.tag in keys)
        return data
      data = expr.eval data, ctx, opts for expr in @exprs
      return data
    predicate: (data) ->
      assert data instanceof Object,
        "data must contain Object data"
      assert (@nodes.some (x) -> x.tag of data),
        "data must contain a matching element"

  new Extension 'choice',
    argument: 'condition'
    data: true
    scope:
      anydata:      '0..n'
      anyxml:       '0..n'
      case:         '0..n'
      choice:       '0..n'
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
    resolve: ->
      if @case? and @nodes.length
        throw @error "cannot contain short-hand non-case data node statement when using case statements"
      
      if @nodes.length
        @extends @nodes.map (node) => (new Yang 'case', node.tag).extends(node)
        @removes @nodes

      if @mandatory?.tag is 'true' and @default?
        throw @error "cannot define 'default' when 'mandatory' is true"
      if @default? and not (@match 'case', @default.tag)?
        throw @error "cannot specify default '#{@default.tag}' without a corresponding case"
      # TODO: need to ensure each nodes in case are unique
    transform: (data, ctx, opts) ->
      unless @case?
        data = expr.eval data, ctx, opts for expr in @exprs
        return data
      for block in @case
        @debug => "checking if case #{block.tag}..."
        try
          data = block.eval data, ctx, opts
          match = block.tag
          break
      switch
        when not match? and @default?
          @debug => "choice fallback to default: #{@default.tag}"
          match = @default.tag
          defcase = @match 'case', @default.tag
          data = expr.eval data, ctx, opts for expr in defcase.exprs
        when not match? and @mandatory?
          throw @error "no matching choice found (mandatory)"
          
      data = attr.eval data, ctx, opts for attr in @attrs when attr.kind isnt 'case'
      # TODO: need to address multiple choices in the data object
      Object.defineProperty data, '@choice', value: match
      return data
    construct: -> @apply arguments... # considered to be a 'node'

  new Extension 'config',
    argument: 'value'
    resolve: ->
      @tag = (@tag is true or @tag is 'true')
      @parent.once 'compiled', =>
        @parent.nodes.map (node) =>
          try node.update this

  new Extension 'contact',
    argument: 'text', yin: true

  new Extension 'container',
    argument: 'name'
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
    predicate: (data={}) ->
      assert typeof data is 'object',
        "data must contain instance of Object"
    construct: -> (new Container this).attach arguments...
    compose: (data, opts={}) ->
      return unless data is Object(data) and not Array.isArray data
      # return unless typeof data is 'object' and Object.keys(data).length > 0
      # return if data instanceof Array
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      parents = opts.parents ? []
      parents.push(data)
      # we want to make sure every property is fulfilled
      for own k of data
        try v = data[k]
        catch then continue
        if v in parents
          @debug => "found circular entry for '#{k}'"
          matches.push (new Yang 'anydata', k, this)
          continue
        for expr in possibilities when expr?.compose?
          @debug => "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose v, tag: k, parents: parents
          break if match?
        return unless match?
        matches.push match
      parents.pop()
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
      default:        '0..n'
      mandatory:      '0..1'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must:           '0..n'
      type:           '0..1'
      unique:         '0..n'
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
      'if-feature': '0..n' # YANG 1.1
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
    argument: 'value'

  new Extension 'error-message',
    argument: 'value'
    yin: true

  new Extension 'extension',
    argument: 'extension-name'
    scope:
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    resolve: ->
      unless @kind is 'extension'
        # NOTE: we can't do a simple 'delete this.argument' since we
        # used delegates to bind getter/setter to the instance
        # prototype
        @argument = false if @argument is 'extension-name'
      @debug => 'setting state of new extension unbound'
      @state.unbound = true
      @once 'bind', =>
        prefix = @lookup 'prefix'
        name = "#{prefix}:#{@tag}"
        @debug => "registering new bound extension '#{name}'"
        opts = @binding
        opts.argument ?= @argument?.valueOf()
        @source = new Extension "#{name}", opts
        if opts.global is true
          @constructor.scope[name] = '0..n'
        for key, value of (opts.target ? {})
          ext = @lookup 'extension', key
          ext?.scope[name] = value
        @constructor.use @source
        @state.unbound = false
        @emit 'bound'

  new Extension 'feature',
    argument: 'name'
    scope:
      description:  '0..1'
      'if-feature': '0..n'
      reference:    '0..1'
      status:       '0..1'
    # transform: (data, ctx) ->
    #   feature = @binding
    #   feature = expr.eval feature, ctx for expr in @exprs when feature?
    #   (new Property @tag, this).attach(ctx.instance) if ctx?.instance? and feature?
    #   return data

  new Extension 'fraction-digits',
    argument: 'value'
    resolve: -> @tag = (Number) @tag

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
    transform: (data, ctx) ->
      unless ctx? # applied directly
        @debug => "applying grouping schema #{@tag} directly"
        prop = (new Container name: @tag, schema: this).set(data, preserve: true)
        data = prop.data
      if ctx?.schema is this
        data = expr.eval data, ctx for expr in @exprs when data?
      return data
      
  new Extension 'identity',
    argument: 'name'
    scope:
      base:        '0..n'
      description: '0..1'
      'if-feature':'0..n' # YANG 1.1
      reference:   '0..1'
      status:      '0..1'
    # TODO: resolve 'base' statements
    resolve: ->
      if @base?
        @lookup 'identity', @base.tag

  new Extension 'if-feature',
    argument: 'if-feature-expr'
    resolve: ->
      expr = Arguments[@argument]?(@tag)
      test = (kw) => @lookup('feature', kw)?.binding?
      target = @parent
      target?.parent?.on 'transforming', =>
        unless expr?(test)
          @debug => "removed #{target.kind}:#{target.tag} due to missing feature(s): #{@tag}"
          target.parent.remove target 

  new Extension 'import',
    argument: 'module'
    scope:
      prefix: '1'
      'revision-date': '0..1'
      description: '0..1' # YANG 1.1
      reference: '0..1' # YANG 1.1
    resolve: ->
      module = @lookup 'module', @tag
      unless module?
        throw @error "unable to resolve '#{@tag}' module"

      # defined as non-enumerable
      Object.defineProperty this, 'module', configurable: true, value: module

      rev = @['revision-date']?.tag
      if rev? and not (@module.match 'revision', rev)?
        throw @error "requested #{rev} not available in #{@tag}"
    transform: (data, ctx) ->
      # below is a very special transform
      if @module.nodes.length and Object.isExtensible(data) and ctx?.store?
        unless ctx.store.has(@module.tag)
          @debug => "IMPORT: absorbing data for '#{@tag}'"
          @module.eval(data, ctx)
        # XXX - we probably don't need to do this...
        # @module.nodes.forEach (x) -> delete data[x.datakey]
      return data

  new Extension 'include',
    argument: 'module'
    scope:
      'revision-date': '0..1'
      description: '0..1' # YANG 1.1
      reference: '0..1' # YANG 1.1
    resolve: ->
      sub = @lookup 'submodule', @tag
      unless sub?
        throw @error "unable to resolve '#{@tag}' submodule"

      mod = switch @root.kind
        when 'module' then @root
        when 'submodule' then @root['belongs-to'].module
        
      unless mod.tag is sub['belongs-to'].tag
        throw @error "requested submodule '#{@tag}' not belongs-to '#{mod.tag}'"

      # defined as non-enumerable
      Object.defineProperty sub['belongs-to'], 'module', configurable: true, value: mod
      for x in sub.compile().children when sub.scope[x.kind] is '0..n' and x.kind isnt 'revision'
        #@debug => "updating parent with #{x.kind}(#{x.tag})"
        @parent.update x
      sub.parent = this

  new Extension 'input',
    data: true
    scope:
      anydata:     '0..n'
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      must:        '0..n' # RFC 7950
      typedef:     '0..n'
      uses:        '0..n'
    #resolve: -> @tag = null if !@tag
    transform: (data, ctx) ->
      return unless typeof data is 'object'
      data = expr.eval data, ctx for expr in @exprs when data?
      return data
    construct: -> (new Container this).attach arguments...
    compose: (data, opts={}) ->
      return unless data instanceof Function
      str = data.toString().replace(STRIP_COMMENTS, '')
      res = str.slice(str.indexOf('(')+1, str.indexOf(')')).match(ARGUMENT_NAMES) ? []
      unless data.length is res.length
        @debug => "argument length mismatch: expected #{data.length} but got #{res.length}"
      (new Yang @tag, null, this).extends res.map (x) -> Yang "anydata #{x};"
      
  new Extension 'key',
    argument: 'value'
    resolve: -> @parent.once 'compiled', =>
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "unable to reference key items as leaf elements", @parent
    predicate: (data) ->
      return unless data instanceof Object
      return if data instanceof Array
      assert (@tag.every (k) -> data.hasOwnProperty k),
        "data must contain values for all key leafs"
    transform: (data, ctx) ->
      return data unless data instanceof Object
      switch
        when Array.isArray(data)
          exists = {}
          data.forEach (item) =>
            return unless typeof item is 'object'
            key = item['@key']
            if exists[key]
              @debug => "found key conflict for #{key} inside #{@parent.tag}"
              throw @error "key conflict for #{key}", item
            exists[key] = true
        when not data.hasOwnProperty '@key'
          Object.defineProperty data, '@key',
            get: (-> (@tag.map (k) -> data[k]).join ',' ).bind this
          #ctx.state.key = data['@key'] if ctx?.state?
      return data

  new Extension 'leaf',
    argument: 'name'
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
      if @mandatory?.tag is 'true' and @default?
        throw @error "cannot define 'default' when 'mandatory' is true"
    predicate: (data) ->
      return if data instanceof Error
      if data instanceof Array
        assert data.length is 1 and data[0] is null,
          "data cannot be an Array"
    transform: (data, ctx, opts) ->
      data = expr.eval data, ctx, opts for expr in @exprs when expr.kind isnt 'type'
      data = @type.apply data, ctx, opts if @type?
      return data
    construct: -> (new Property this).attach arguments...
    compose: (data, opts={}) ->
      return if data instanceof Array
      return if data instanceof Object and Object.keys(data).length > 0
      type = (@lookup 'extension', 'type')?.compose? data
      return unless type?
      @debug => "detected '#{opts.tag}' as #{type?.tag}"
      (new Yang @tag, opts.tag, this).extends type

  new Extension 'leaf-list',
    argument: 'name'
    data: true
    scope:
      config:         '0..1'
      default:        '0..n' # RFC 7950
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

    predicate: (data, opts={}) ->
      assert data instanceof Array, "data must contain an Array" if data? and opts.strict
    transform: (data, ctx, opts) ->
      data = @default?.keys unless data?
      data = data.split(/\s*,\s*/) if typeof data is 'string'
      data = [ data ] if data? and not Array.isArray(data)
      if data?
        data = Array.from(new Set(data)).filter (x) -> x != undefined && x != null
      data = expr.eval data, ctx, opts for expr in @exprs when expr.kind isnt 'type'
      data = @type.apply data, ctx, opts if @type?
      return data
    construct: -> (new Property this).attach arguments...
    compose: (data, opts={}) ->
      return unless data instanceof Array
      type_ = @lookup 'extension', 'type'
      types = []
      for item in data
        res = type_.compose? item
        return unless res?
        types.push res
      # return unless data.every (x) -> typeof x isnt 'object'
      # types = data.map (x) -> type_.compose? x
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
      unique:       '0..n'
      uses:         '0..n'
      when:         '0..1'

    predicate: (data={}) ->
      assert data instanceof Object, "data must be an Object"
    transform: (data, ctx, opts) ->
      return unless data?
      if Array.isArray(data)
        data = data.map (item) => (new List.Item this).attach(item, ctx, opts)
      else
        data = node.eval data, ctx, opts for node in @nodes when data?
      data = attr.eval data, ctx, opts for attr in @attrs when data?
      return data
    construct: -> (new List this).attach arguments...
    compose: (data, opts={}) ->
      return unless data instanceof Array and data.length > 0
      return unless data.every (x) -> typeof x is 'object'

      # TODO: inspect more than first element
      data = data[0]
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      parents = opts.parents ? []
      parents.push(data)
      for own k, v of data
        if v in parents
          @debug => "found circular entry for '#{k}'"
          matches.push (new Yang 'anydata', k, this)
          continue
        for expr in possibilities when expr?
          match = expr.compose? v, tag: k, parents: parents
          break if match?
        return unless match?
        matches.push match
      parents.pop()
      (new Yang @tag, opts.tag, this).extends matches...

  new Extension 'mandatory',
    argument: 'value'
    resolve:   -> @tag = (@tag is true or @tag is 'true')
    predicate: (data) ->
      assert @tag isnt true or data? or @parent.binding?,
        "data must be defined"

  new Extension 'max-elements',
    argument: 'value'
    resolve: -> @tag = (Number) @tag unless @tag is 'unbounded'
    predicate: (data) ->
      assert @tag is 'unbounded' or data not instanceof Array or data.length <= @tag,
        "data must contain less than maximum entries (#{@tag})"

  new Extension 'min-elements',
    argument: 'value'
    resolve: -> @tag = (Number) @tag
    predicate: (data) ->
      assert data not instanceof Array or data.length >= @tag,
        "data must contain more than minimum entries (#{@tag})"

  # TODO
  new Extension 'modifier',
    argument: 'value'
    resolve: -> @tag = @tag is 'invert-match'

  new Extension 'module',
    argument: 'name'
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
        @debug => "found #{@extension.length} new extension(s)"
    transform: (data, ctx, opts) ->
      data = expr.eval data, ctx, opts for expr in @exprs when data? and expr.kind isnt 'extension'
      return data
    construct: -> (new Model name: @tag, schema: this).attach arguments...

  # TODO
  new Extension 'must',
    argument: 'condition'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'namespace',
    argument: 'value'

  new Extension 'notification',
    argument: 'event'
    data: true
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
      must:         '0..n' # RFC 7950
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      uses:         '0..n'
    construct: -> (new Notification this).attach arguments...

  new Extension 'ordered-by',
    argument: 'value'

  new Extension 'organization',
    argument: 'text'
    yin: true

  new Extension 'output',
    data: true
    scope:
      anydata:     '0..n'
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      must:        '0..n' # RFC 7950
      typedef:     '0..n'
      uses:        '0..n'
    transform: (data, ctx) ->
      return data if data instanceof Promise
      data = expr.eval data, ctx for expr in @exprs when data?
      return data
    construct: -> (new Container this).attach arguments...

  new Extension 'path',
    argument: 'value'
    resolve: -> @tag = @normalizePath @tag

  new Extension 'pattern',
    argument: 'value'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      modifier:        '0..1'
      reference:       '0..1'
    resolve: -> @tag = new RegExp "^(?:#{@tag})$"

  new Extension 'position',
    argument: 'value'

  new Extension 'prefix',
    argument: 'value'
    resolve: -> # should validate prefix naming convention

  new Extension 'presence',
    argument: 'value'

  new Extension 'range',
    argument: 'value'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  new Extension 'reference',
    argument: 'value'

  new Extension 'refine',
    argument: 'target-node'
    scope:
      default:        '0..1'
      description:    '0..1'
      reference:      '0..1'
      config:         '0..1'
      'if-feature':   '0..n' # YANG 1.1
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

      @debug => "APPLY #{this} to #{target}"
      # TODO: revisit this logic, may need to 'merge' the new expr into existing expr
      @exprs.forEach (expr) -> switch
        when target.hasOwnProperty expr.kind
          if expr.kind in ['must', 'if-feature'] then target.extends expr
          else target.merge expr, replace: true
        else target.extends expr

  new Extension 'require-instance',
    argument: 'value'
    resolve: -> @tag = (@tag is true or @tag is 'true')

  new Extension 'revision',
    argument: 'date'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1' # deviation from RFC 6020

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

    predicate: (data=->) ->
      assert data instanceof Function,
        "data must be a Function"
    resolve: ->
      @extends (new Yang 'input') unless @input
      @extends (new Yang 'output') unless @output
    transform: (data, ctx, opts) ->
      return unless data?
      unless data instanceof Function
        @debug => data
        # TODO: allow data to be a 'string' compiled into a Function?
        throw @error "expected a function but got a '#{typeof data}'"
      data = attr.eval data, ctx, opts for attr in @attrs
      return data
    construct: -> (new Method this).attach arguments...

  new Extension 'status',
    argument: 'value'
    resolve: -> @tag = @tag ? 'current'

  new Extension 'submodule',
    argument: 'name'
    scope:
      anydata:        '0..n'
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
      base:               '0..n'
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
      if @type? and @tag isnt 'union'
        throw @error "cannot have additional type definitions unless 'union'"
      
      typedef = @lookup 'typedef', @tag
      unless typedef?
        @debug => @parent
        throw @error "unable to resolve typedef for #{@tag}"
      if typedef.type?
        @once 'compiled', =>
          for expr in typedef.type.exprs
            try @merge expr
      convert = typedef.convert
      convert ?= typedef.compile().convert
      unless convert?
        throw @error "no convert found for #{typedef.tag}"
      @state.basetype = typedef.basetype ? typedef.state.basetype
      @convert = convert.bind this
      if @parent? and @parent.kind isnt 'type'
        try @parent.extends typedef.default, typedef.units
    transform: (data, ctx, opts) ->
      return data unless data isnt undefined and (data instanceof Array or data not instanceof Object)
      if data instanceof Array
        res = data.map (x) => @convert x, ctx, opts
        ctx.defer(data) if not ctx.attached and res.some (x) -> x instanceof Error
      else
        res = @convert data, ctx, opts
        ctx.defer(data) if not ctx.attached and res instanceof Error
      return res
    compose: (data, opts={}) ->
      return if data instanceof Function
      #return if data instanceof Object and Object.keys(data).length > 0
      typedefs = @lookup 'typedef'
      for typedef in typedefs.concat(tag: 'unknown')
        @debug => "checking if #{typedef.tag}"
        try break if (typedef.convert data) isnt undefined
        catch e then @debug => e.message
      return if typedef.tag is 'unknown'
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
        @state.basetype = @type.state.basetype
        return
      builtin = @lookup 'typedef', @tag
      unless builtin?
        throw @error "unable to resolve '#{@tag}' built-in type"
      @state.basetype = builtin.basetype
      @convert = builtin.convert

  new Extension 'unique',
    argument: 'tag'
    resolve: -> @parent.once 'compiled', =>
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.locate(k)?.kind is 'leaf')
        throw @error "referenced unique items do not have leaf elements"
    predicate: (data) ->
      return unless data instanceof Array
      seen = {}
      isUnique = data.every (item) =>
        return true unless @tag.every (k) -> item[k]?
        key = @tag.reduce ((a,b) -> a += item[b]), ''
        return false if seen[key]
        seen[key] = true
        return true
      assert isUnique,
        "data must contain unique entries of #{@tag}"

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

      # NOTE: declared as non-enumerable
      #Object.defineProperty this, 'grouping', value: 
      unless @when?
        ref = @state.grouping = grouping.clone().compile()
        @debug => "extending with #{ref.nodes.length} elements"
        @parent.extends ref.nodes
      else
        @parent.on 'transformed', (data) =>
          data = expr.apply data for expr in @exprs if data?
    transform: (data) -> data

  new Extension 'value',
    argument: 'value' # required

  # TODO
  new Extension 'when',
    argument: 'condition'
    scope:
      description: '0..1'
      reference:   '0..1'

  new Extension 'yang-version',
    argument: 'value'

  new Extension 'yin-element',
    argument: 'value'

]
