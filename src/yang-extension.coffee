Expression = require './expression'
Yang       = require './yang'
Property   = require './property'
XPath      = require './xpath'

class Extension extends Expression
  @scope =
    argument:    '0..1'
    description: '0..1'
    reference:   '0..1'
    status:      '0..1'

  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    spec.scope ?= {}
    super 'extension', name, spec

    Object.defineProperties this,
      argument: value: spec.argument
      compose:  value: spec.compose

exports = module.exports = Extension
exports.builtins = [

  new Extension 'action',
    argument: 'name'
    node: true
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
      func = data[@tag] ? @binding ? (a,b,c) => throw @error "handler function undefined"
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless func.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      func = expr.apply func for expr in @exprs
      func.async = true
      (new Property @tag, func, schema: this).join data

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
          @parent.grouping.locate @tag

      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      unless @when?
        @debug? "augmenting '#{target.kind}:#{target.tag}'"
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

    construct: (data) ->
      return unless data?
      return data if @tag is true and data not instanceof Function

      unless data instanceof Function
        throw @error "cannot set data on read-only element"

      func = ->
        v = data.call this
        v = expr.apply v for expr in @schema.exprs when expr.kind isnt 'config'
        return v
      func.computed = true
      return func

    predicate: (data) -> not data? or @tag is true or data instanceof Function

  new Extension 'contact', argument: 'text', yin: true

  new Extension 'container',
    argument: 'name'
    node: true
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
      obj = data[@datakey] ? @binding
      obj = expr.apply obj for expr in @exprs if obj?
      (new Property @datakey, obj, schema: this).join data

    predicate: (data) -> not data?[@datakey]? or data[@datakey] instanceof Object

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
          match = expr.compose? v, tag: k
          break if match?
        return unless match?
        matches.push match

      (new Yang @tag, opts.tag, this).extends matches...

  new Extension 'default',
    argument: 'value'
    construct: (data) -> data ? @tag

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
    resolve: ->

  new Extension 'feature',
    argument: 'name'
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
    resolve: ->
      unless (@lookup 'feature', @tag)?
        console.warn "should be turned off..."
        #@define 'status', off

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
        (@parent.update x).resolve()

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

    construct: (func) ->
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      return (input, resolve, reject) ->
        # validate input prior to calling 'func'
        try input = expr.apply input for expr in @schema.input.exprs
        catch e then reject e
        func.call this, input, resolve, reject

  new Extension 'key',
    argument: 'value'
    resolve: -> @parent.once 'resolve:after', =>
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "unable to reference key items as leaf elements", @parent

    construct: (data) ->
      return data unless data instanceof Object
      list = data
      list = [ list ] unless list instanceof Array
      exists = {}
      for item in list when item instanceof Object
        unless item.hasOwnProperty '@key'
          Object.defineProperty item, '@key',
            get: (->
              @debug? "GETTING @key from #{this} using #{@tag}:"
              (@tag.map (k) -> item[k]).join ','
            ).bind this
        key = item['@key']
        if exists[key] is true
          throw @error "key conflict for #{key}"
        exists[key] = true

        #(new Element '@key', key, schema: this, enumerable: false).update item

        if data instanceof Array
          @debug? "defining a direct key mapping for '#{key}'"
          key = "__#{key}__" if (Number) key
          (new Property key, item, schema: this, enumerable: false).join data
      return data

    predicate: (data) ->
      return true if data instanceof Array
      @tag.every (k) => data[k]?

  new Extension 'leaf',
    argument: 'name'
    node: true
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

    construct: (data={}) ->
      return data unless data?.constructor is Object
      val = data[@datakey] ? @binding
      console.debug? "expr on leaf #{@tag} for #{val} with #{@exprs.length} exprs"
      val = expr.apply val for expr in @exprs when expr.kind isnt 'type'
      val = @type.apply val if @type?
      (new Property @datakey, val, schema: this).join data

    compose: (data, opts={}) ->
      return if data instanceof Array
      return if data instanceof Object and Object.keys(data).length > 0
      type = (@lookup 'extension', 'type')?.compose? data
      return unless type?
      @debug? "leaf #{opts.tag} found #{type?.tag}"
      (new Yang @tag, opts.tag, this).extends type

  new Extension 'leaf-list',
    argument: 'name'
    node: true
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

    construct: (data={}) ->
      return data unless data instanceof Object
      ll = data[@tag] ? @binding
      ll = expr.apply ll for expr in @exprs if ll?
      (new Property @tag, ll, schema: this).join data

    predicate: (data) -> not data[@tag]? or data[@tag] instanceof Array

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
    node: true
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
      list = data[@datakey] ? @binding
      if list instanceof Array
        list = list.map (li, idx) =>
          unless li instanceof Object
            throw @error "list item entry must be an object"
          li = expr.apply li for expr in @exprs
          li
      @debug? "processing list #{@datakey} with #{@exprs.length}"
      list = expr.apply list for expr in @exprs if list?
      if list instanceof Array
        list.forEach (li, idx, self) => new Property @datakey, li, schema: this, parent: self
        # TODO: should this be Array.prototype extensions?
        Object.defineProperties list,
          add: value: (items...) ->
            # TODO: schema qualify the added items
            for item in items when item?.__ instanceof Property
              item.__.parent = this
            @push items...
            @__.emit 'create', @__, items...
            @__.emit 'update', @__
          remove: value: (key) ->
            console.log "remove #{key} from list with #{@length} entries"
            items = []
            for idx, item of this when item['@key'] is key
              @splice idx, 1
              items.push item
            @__.emit 'delete', @__, items...
            @__.emit 'update', @__

      (new Property @datakey, list, schema: this).join data

    predicate: (data) -> not data[@datakey]? or data[@datakey] instanceof Object

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
    predicate: (data) -> @tag isnt true or data?

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
        @debug? "found #{@extension.length} new extension(s)"

    construct: (data={}) ->
      return data unless data instanceof Object
      data = expr.apply data for expr in @exprs
      #new Property @tag, data, schema: this
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
          match = expr.compose? v, tag: k
          break if match?
        unless match?
          console.log "unable to find match for #{k}"
          console.log v
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
    construct: ->

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
    construct: (func) ->
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      return (input, resolve, reject) ->
        func.apply this, [
          input,
          (res) =>
            # validate output prior to calling 'resolve'
            try res = expr.apply res for expr in @schema.output.exprs
            catch e then reject e
            resolve res
          reject
        ]

  new Extension 'path',
    argument: 'value'
    resolve: -> @tag = new XPath @tag

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
      target = @parent.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      @debug? "APPLY #{this} to #{target}"
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
    node: true
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
      rpc = data[@tag] ? @binding ? (a,b,c) => throw @error "handler function undefined"
      unless rpc instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless rpc.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      rpc = expr.apply rpc for expr in @exprs
      rpc.async = true
      (new Property @tag, rpc, schema: this).join data

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
        console.log @parent
        throw @error "unable to resolve typedef for #{@tag}"

      if typedef.type?
        @update expr for expr in typedef.type.exprs

      @convert = typedef.convert?.bind this

      if @parent? and @parent.kind isnt 'type'
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
        try break if (typedef.convert data) isnt undefined
        catch e then @debug? e
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
        @convert = @type.resolve().convert
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
        key = @tag.reduce ((a,b) -> a += item[b] ), ''
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

      # NOTE: declared as non-enumerable
      Object.defineProperty this, 'grouping', value: grouping.clone()
      unless @when?
        @debug? "extending #{@grouping} into #{@parent}"
        @parent.extends @grouping.elements.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        @parent.on 'apply:after', (data) =>
          data = expr.apply data for expr in @grouping.exprs if data?

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
