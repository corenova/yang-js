#
# YANG version 1.0 built-in language extensions
#
Expression = require './expression'
 
module.exports = [

  new Expression 'argument',
    kind: 'extension'
    argument: 'arg-type' # required
    scope:
      'yin-element': '0..1'

  new Expression 'augment',
    kind: 'extension'
    scope:
      anyxml:        '0..n'
      case:          '0..n'
      choice:        '0..n'
      container:     '0..n'
      description:   '0..1'
      'if-feature':  '0..n'
      leaf:          '0..n'
      'leaf-list':   '0..n'
      list:          '0..n'
      reference:     '0..1'
      status:        '0..1'
      uses:          '0..n'
      when:          '0..1'
    construct: (data={}) ->
      return data unless data instanceof Object
      # prop = @propertize null, data, static: true
      # target = prop.get @tag
      # target = expr.eval target for expr in @expressions
      return data

  new Expression 'belongs-to',
    kind: 'extension'
    scope:
      prefix: '1'
    resolve: -> @parent[@prefix.tag] = @lookup 'module', @tag

  # TODO
  new Expression 'bit',
    kind: 'extension'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'

  # TODO
  new Expression 'case',
    kind: 'extension'
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
  new Expression 'choice',
    kind: 'extension'
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

  new Expression 'config',
    kind: 'extension'
    resolve: -> @tag = (@tag is true or @tag is 'true')
    construct: (data) ->
      return data if @tag is true or not data?
      # if config: false, it can still accept a Function
      unless data instanceof Function
        throw @error "cannot set data on read-only element"
      func = ->
        v = data.call this
        v = expr.eval v for expr in @expr.expressions when expr.kind isnt 'config'
        return v
      func.computed = true
      return func
    predicate: (data) -> not data? or @tag is true or data instanceof Function

  new Expression 'container',
    kind: 'extension'
    scope:
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
      presence:     '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      uses:         '0..n'
      when:         '0..1'
    construct: (data={}) -> 
      return data unless data instanceof Object
      obj = data[@tag]
      obj = expr.eval obj for expr in @expressions if obj?
      @update data, @tag, obj
    predicate: (data) -> not data?[@tag]? or data[@tag] instanceof Object

  new Expression 'default',
    kind: 'extension'
    construct: (data) -> data ? @tag

  # TODO
  new Expression 'deviate',
    kind: 'extension'
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
  new Expression 'deviation',
    kind: 'extension'
    scope:
      description: '0..1'
      deviate:     '1..n'
      reference:   '0..1'

  new Expression 'enum',
    kind: 'extension'
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

  new Expression 'extension',
    kind: 'extension'
    argument: 'extension-name' # required
    scope: 
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    resolve: -> @origin = (@lookup 'extension', @tag) ? {}

  new Expression 'feature',
    kind: 'extension'
    scope:
      description:  '0..1'
      'if-feature': '0..n'
      reference:    '0..1'
      status:       '0..1'
    resolve: ->
      if @status.tag is 'unavailable'
        console.warn "feature #{@tag} is unavailable"
      @on 'create', (element) =>
        element.state = require element.kw
      #   # if typeof ctx.feature is 'object'
      #   #   delete ctx.feature[tag]
      #   # else
      #   #   delete ctx.feature

  new Expression 'grouping',
    kind: 'extension'
    scope:
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      description: '0..1'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      reference:   '0..1'
      status:      '0..1'
      typedef:     '0..n'
      uses:        '0..n'

  new Expression 'identity',
    kind: 'extension'
    scope:
      base:        '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    # TODO: resolve 'base' statements
    resolve: -> 
      if @base?
        @lookup 'identity', @base.tag

  new Expression 'if-feature',
    kind: 'extension'
    resolve: ->
      unless (@lookup 'feature', @tag)?
        console.warn "should be turned off..."
        #@define 'status', off

  new Expression 'import',
    kind: 'extension'
    scope:
      prefix: 1
      'revision-date': '0..1'
    resolve: ->
      m = @lookup 'module', @tag
      unless m?
        throw @error "unable to resolve '#{@tag}' module"

      rev = @['revision-date'].tag
      if rev? and not (m.contains 'revision', rev)
        throw @error "requested #{rev} not available in #{@tag}"

      # should it be preprocessed map of m (just declared meta-data)?
      @parent[@prefix.tag] = m

      # TODO: Should be handled in extension construct
      # go through extensions from imported module and update 'scope'
      for k, v of m.extension ? {}
        for pkey, scope of v.resolve 'parent-scope'
          target = @parent.resolve 'extension', pkey
          target?.scope["#{@prefix.tag}:#{k}"] = scope

  new Expression 'include',
    kind: 'extension'
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

  new Expression 'input',
    kind: 'extension'
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
        try input = expr.eval input for expr in @expr.input.expressions
        catch e then reject e
        func.call this, input, resolve, reject

  new Expression 'key',
    kind: 'extension'
    resolve: ->
      @tag = @tag.split ' '
      @parent.once 'created', (expr) =>
        unless (@tag.every (k) -> expr.contains 'leaf', k)
          throw @error "referenced key items do not have leaf elements"
    construct: (data) ->
      return data unless data instanceof Array
      exists = {}
      for item in data when item instanceof Object
        key = (@tag.map (k) -> item[k]).join ','
        if exists[key] is true
          throw @error "key conflict for #{key}"
        exists[key] = true
        @update item, '@key', key, enumerable: false
        
        console.debug? "defining a direct key mapping for '#{key}'"
        key = "__#{key}__" if (Number) key
        @update data, key, item, enumerable: false
      return data
    predicate: (data) ->
      return true if data instanceof Array
      @tag.every (k) => data[k]?

  new Expression 'leaf',
    kind: 'extension'
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
      val = data[@tag]
      console.debug? "expr on leaf #{@tag} for #{val} with #{@expressions.length} exprs"
      val = expr.eval val for expr in @expressions
      @update data, @tag, val

  new Expression 'leaf-list',
    kind: 'extension'
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
      ll = data[@tag]
      ll = expr.eval ll for expr in @expressions if ll?
      @update data, @tag, ll

  new Expression 'length',
    kind: 'extension'
    scope:
      description: '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference: '0..1'

  new Expression 'list',
    kind: 'extension'
    scope:
      anyxml: '0..n'
      choice: '0..n'
      config: '0..1'
      container: '0..n'
      description: '0..1'
      grouping: '0..n'
      'if-feature': '0..n'
      key: '0..1'
      leaf: '0..n'
      'leaf-list': '0..n'
      list: '0..n'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must: '0..n'
      'ordered-by': '0..1'
      reference: '0..1'
      status: '0..1'
      typedef: '0..n'
      unique: '0..1'
      uses: '0..n'
      when: '0..1'
    construct: (data={}) ->
      return data unless data instanceof Object
      list = data[@tag]
      list = list?.map (li, idx) =>
        unless li instanceof Object
          throw @error "list item entry must be an object"
        li = expr.eval li for expr in @expressions
        li
      console.debug? "processing list #{@tag} with #{@expressions.length}"
      list = expr.eval list for expr in @expressions if list?
      list?.forEach (li, idx, self) =>
        @propertize idx, li, parent: self
      @update data, @tag, list

  new Expression 'mandatory',
    kind: 'extension'
    resolve:   -> @tag = (@tag is true or @tag is 'true')
    predicate: (data) -> @tag isnt true or data?

  new Expression 'max-elements',
    kind: 'extension'
    resolve: -> @tag = (Number) @tag unless @tag is 'unbounded'
    predicate: (data) -> @tag is 'unbounded' or data not instanceof Array or data.length <= @tag

  new Expression 'min-elements',
    kind: 'extension'
    resolve: -> @tag = (Number) @tag
    predicate: (data) -> data not instanceof Array or data.length >= @tag 

  new Expression 'module',
    kind: 'extension'
    argument: 'name' # required
    scope:
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
      delete this[@prefix.tag] if @prefix? # clean-up circular ref to itself
      if @extension?.length > 0
        console.debug? "[module:#{@tag}] found #{@extension.length} new extension(s)"
    construct: (data={}) ->
      return data unless data instanceof Object
      data = expr.eval data for expr in @expressions
      @propertize @tag, data
      return data
      # TODO
      # for target, change of @parent.get 'augment'
      #   (@locate target)?.extends change.elements(create:true)...
      # return this

      # for k, v of params.import
      #   modules[k] = @lookup k
      # (synth.Store params, -> @set name: tag, modules: modules).bind children

  # TODO
  new Expression 'must',
    kind: 'extension'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  # TODO
  new Expression 'notification',
    kind: 'extension'
    scope:
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

  new Expression 'output',
    kind: 'extension'
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
            try res = expr.eval res for expr in @expr.output.expressions
            catch e then reject e
            resolve res
          reject
        ]

  new Expression 'path',
    kind: 'extension'
    resolve: -> @tag = @tag.replace /[_]/g, '.'

  new Expression 'pattern',
    kind: 'extension'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'
    resolve: -> @tag = new RegExp @tag

  new Expression 'prefix',
    kind: 'extension'
    resolve: -> @parent[@tag] = @parent

  new Expression 'range',
    kind: 'extension'
    scope:
      description:     '0..1'
      'error-app-tag': '0..1'
      'error-message': '0..1'
      reference:       '0..1'

  # TODO
  new Expression 'refine',
    kind: 'extension'
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

  new Expression 'require-instance',
    kind: 'extension'
    resolve: -> @tag = (@tag is true or @tag is 'true')

  new Expression 'revision',
    kind: 'extension'
    scope:
      description: '0..1'
      reference:   '0..1'

  new Expression 'rpc',
    kind: 'extension'
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
      rpc = data[@tag] ? (a,b,c) => throw @error "handler function undefined"
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
      func.async ?= true
      @update data, @tag, func

  new Expression 'submodule',
    kind: 'extension'
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

  new Expression 'status',
    kind: 'extension'
    resolve: -> @tag = @tag ? 'current'

  new Expression 'type',
    kind: 'extension'
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
      delete @enumValue
      exists = @lookup 'typedef', @tag
      unless exists?
        throw @error "unable to resolve typedef for #{@tag}"
      @convert = exists.convert.bind null, this
      # TODO: deal with typedef overrides
      # @parent.once 'created', (yang) ->
      #   yang.extends exists.expressions('default','units','type')...
    construct: (data) -> switch
      when data instanceof Function then data
      when data instanceof Array then data.map (x) => @convert x
      else @convert data

  new Expression 'typedef',
    kind: 'extension'
    scope:
      default:     '0..1'
      description: '0..1'
      units:       '0..1'
      type:        '0..1'
      reference:   '0..1'
    resolve: -> 
      if @type?
        @convert = @type.convert
        return
      builtin = @lookup 'typedef', @tag
      unless builtin?.construct instanceof Function
        throw @error "unable to resolve '#{@tag}' built-in type"
      @convert = (schemas..., value) =>
        schema = schemas.reduce ((a,b) ->
          a[k] = v for own k, v of b; a
        ), {}
        # composite =
        #   new Expression @tag, kind: 'typedef'
        #   .extends (schemas.reduce ((a,b) -> a.concat b.expressions),[])...
        builtin.construct.call schema, value

  new Expression 'unique',
    kind: 'extension'
    resolve: ->
      @tag = @tag = @tag.split ' '
      @parent.once 'created', (expr) =>
        unless (@tag.every (k) -> expr.contains 'leaf', k)
          throw @error "referenced unique items do not have leaf elements"
    predicate: (data) ->
      return true unless data instanceof Array
      seen = {}
      data.every (item) =>
        key = @tag.reduce ((a,b) -> a += item[b] ), ''
        return false if seen[key]
        seen[key] = true
        return true
    
  new Expression 'uses',
    kind: 'extension'
    scope:
      augment:      '0..n'
      description:  '0..1'
      'if-feature': '0..n'
      refine:       '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
    resolve: -> 
      grouping = (@lookup 'grouping', @tag)
      unless grouping?
        throw @error "unable to resolve #{@tag} grouping definition"
    construct: (data={}) ->
      return data unless data instanceof Object
      data = expr.eval data for expr in (@lookup 'grouping', @tag).expressions
      data = expr.eval data for expr in @expressions
      return data

  new Expression 'when',
    kind: 'extension'
    scope:
      description: '0..1'
      reference:   '0..1'

  new Expression 'yin-element',
    kind: 'extension'
    argument: 'value' # required

  # Special non RFC-6020 extension
  new Expression 'composition',
    kind: 'extension'
    argument: 'name'
    scope:
      description:  '0..1'
      composition:  '0..n'
      contact:      '0..1'
      module:       '0..n'
      namespace:    '0..1'
      notification: '0..n'
      organization: '0..1'
      reference:    '0..1'
      rpc:          '0..n'

]
