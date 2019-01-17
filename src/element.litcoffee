# Element - cascading element tree

## Class Element

    debug = require('debug')('yang:element')
    delegate = require 'delegates'
    Emitter = require('events').EventEmitter
    Emitter.defaultMaxListeners = 100
    
    class Element
      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc
      @use: ->
        res = [].concat(arguments...)
          .filter (x) -> x?
          .map (elem) =>
            exists = Element::match.call this, elem.kind, elem.tag
            if exists?
              debug "use: using previously loaded '#{elem.kind}:#{elem.tag}'"
              return exists
            try Element::merge.call this, elem
            catch e
              throw @error "use: unable to merge '#{elem.kind}:#{elem.tag}'", e
        return switch 
          when res.length > 1  then res
          when res.length is 1 then res[0]
          else undefined
      @debug: -> debug "[#{@uri}]", arguments...
      @error: (err, ctx=this) ->
        unless err instanceof Error
          err = new Error "[#{@uri}] #{err}"
        err.name = 'ElementError'
        err.context = ctx
        return err

      constructor: (@kind, @tag, source={}) ->
        unless @kind?
          throw @error "must supply 'kind' to create a new Element"
        unless source instanceof Object
          throw @error "must supply 'source' as an object"
        Object.defineProperties this,
          parent: value: null, writable: true
          origin: value: null, writable: true
          source: value: source, writable: true
          index:  value: 0, writable: true
          state:  value: {}, writable: true
          emitter: value: new Emitter

      error: @error
      debug: @debug

      delegate @prototype, 'emitter'
        .method 'emit'
        .method 'once'
        .method 'on'

      delegate @prototype, 'source'
        .getter 'scope'
        .getter 'construct'

      delegate @prototype, 'cache'
        .getter 'elements'
        .getter 'nodes'
        .getter 'attrs'

### Computed Properties

      @property 'uri',
        get: ->
          mark = @kind
          mark += "(#{@tag})" if @tag? and @source.argument not in [ 'value', 'text' ]
          return mark unless @parent instanceof Element
          return "#{@parent.uri}/#{mark}"

      @property 'root',
        get: -> switch
          when @parent instanceof Element then @parent.root
          when @origin instanceof Element then @origin.root
          else this

      @property 'node',
        get: -> @construct instanceof Function

      @property 'cache',
        get: ->
          unless this._cache?
            elements = (v for own k, v of this when k not in [ 'parent', 'origin', 'tag', '_cache' ])
              .reduce ((a,b) -> switch
                when b instanceof Element then a.concat b
                when b instanceof Array
                  a.concat b.filter (x) -> x instanceof Element
                else a
              ), []
            elements = elements.sort (a,b) -> a.index - b.index
            this._cache =
              elements: elements
              nodes: elements.filter (x) -> x.node is true
              attrs: elements.filter (x) -> x.node is false
          return this._cache

      @property '*',     get: -> @nodes
      @property '..',    get: -> @parent

## Instance-level methods

### clone

      clone: ->
        @debug "cloning #{@kind}:#{@tag} with #{@elements.length} elements"
        copy = (new @constructor @kind, @tag, @source).extends @elements.map (x) =>
          c = x.clone()
          c.parent = x.parent unless x.parent is this
          return c
        copy.state  = @state
        copy.origin = @origin ? this
        return copy

### extends (elements...)

This is the primary mechanism for defining sub-elements to become part
of the element tree

      extends: ->
        elems = ([].concat arguments...).filter (x) -> x? and !!x
        return this unless elems.length > 0
        elems.forEach (expr) => @merge expr
        @emit 'change', elems...
        return this

### merge (element)

This helper method merges a specific Element into current Element
while performing `@scope` validations.

      merge: (elem, opts={}) ->
        unless elem instanceof Element
          throw @error "cannot merge invalid element into Element", elem
        elem.index = @elements.length if @elements?
        elem.parent = this
        this._cache = null 

        _merge = (item) ->
          if not item.node or opts.append or item.tag not in (@tags ? [])
            @push item
            true
          else if opts.replace is true
            for x, i in this when x.tag is item.tag
              @splice i, 1, item
              break
            true
          else false

        unless @scope?
          unless @hasOwnProperty elem.kind
            @[elem.kind] = elem
            return elem

          unless Array.isArray @[elem.kind]
            exists = @[elem.kind]
            @[elem.kind] = [ exists ]
            Object.defineProperty @[elem.kind], 'tags',
              get: (-> @map (x) -> x.tag ).bind @[elem.kind]
              
          unless _merge.call @[elem.kind], elem
            throw @error "constraint violation for '#{elem.kind} #{elem.tag}' - cannot define more than once"

          return elem

        unless elem.kind of @scope
          if elem.scope?
            @debug @scope
            throw @error "scope violation - invalid '#{elem.kind}' extension found"
          else
            @scope[elem.kind] = '*' # this is hackish...

        switch @scope[elem.kind]
          when '0..n', '1..n', '*'
            unless @hasOwnProperty elem.kind
              @[elem.kind] = []
              Object.defineProperty @[elem.kind], 'tags',
                get: (-> @map (x) -> x.tag ).bind @[elem.kind]
            unless _merge.call @[elem.kind], elem
              throw @error "constraint violation for '#{elem.kind} #{elem.tag}' - already defined"
          when '0..1', '1'
            unless @hasOwnProperty elem.kind
              @[elem.kind] = elem
            else if opts.replace is true
              @debug "replacing pre-existing #{elem.kind}"
              @[elem.kind] = elem
            else
              throw @error "constraint violation for '#{elem.kind}' - cannot define more than once"
          else
            throw @error "unrecognized scope constraint defined for '#{elem.kind}' with #{@scope[elem.kind]}"

        return elem

      removes: ->
        elems = ([].concat arguments...).filter (x) -> x? and !!x
        return this unless elems.length > 0
        elems.forEach (expr) => @remove expr
        @emit 'change', elems...
        return this

      remove: (elem) ->
        unless elem instanceof Element
          throw @error "cannot remove a non-Element from an Element", elem

        #@debug "update with #{elem.kind}/#{elem.tag}"
        exists = Element::match.call this, elem.kind, elem.tag
        return this unless exists?

        if Array.isArray @[elem.kind]
          @[elem.kind] = @[elem.kind].filter (x) -> x.tag isnt elem.tag
          delete @[elem.kind] unless @[elem.kind].length
        else
          delete @[elem.kind]

        this._cache = null
        return this

### update (element)

This alternative form of [merge](#merge-element) performs conditional
merge based on existence check. It is considered *safer* alternative
to direct [merge](#merge-element) call.

      # performs conditional merge based on existence
      update: (elem) ->
        unless elem instanceof Element
          throw @error "cannot update a non-Element into an Element", elem

        #@debug "update with #{elem.kind}/#{elem.tag}"
        exists = Element::match.call this, elem.kind, elem.tag
        return @merge elem unless exists?

        #@debug "update #{exists.kind} in-place for #{elem.elements.length} elements"
        exists.update target for target in elem.elements
        return exists

      # Looks for matching Elements using kind and tag
      # Direction: up the hierarchy (towards root)
      lookup: (kind, tag) ->
        res = switch
          when this not instanceof Object then undefined
          when this instanceof Element then @match kind, tag
          else Element::match.call this, kind, tag
        res ?= switch
          when @origin? then Element::lookup.apply @origin, arguments
          when @parent? then Element::lookup.apply @parent, arguments
          else Element::match.call @constructor, kind, tag
        return res

      # Looks for matching Elements using YPATH notation
      # Direction: down the hierarchy (away from root)
      at: -> @locate arguments...
      locate: (ypath) ->
        return unless ypath?
        if typeof ypath is 'string'
          @debug "locate: #{ypath}"
          ypath = ypath.replace /\s/g, ''
          if (/^\//.test ypath) and this isnt @root
            return @root.locate ypath
          [ key, rest... ] = ypath.split('/').filter (e) -> !!e
        else
          @debug "locate: #{ypath.join('/')}"
          [ key, rest... ] = ypath
        return this unless key?

        match = switch
          when key is '..' then @match key
          else @match '*', key

        return switch
          when rest.length is 0 then match
          else match?.locate rest

      # Looks for a matching Element(s) in immediate sub-elements
      match: (kind, tag) ->
        return unless kind? and @[kind]?
        return @[kind] unless tag?

        match = @[kind]
        match = [ match ] unless match instanceof Array
        return match if tag is '*'

        for elem in match when elem instanceof Element
          key = if elem.tag? then elem.tag else elem.kind
          return elem if tag is key
        return undefined

### toJSON

Converts the Element into a JS object

      toJSON: (opts={ tag: true, extended: false }) ->
        #@debug "converting #{@kind} toJSON with #{@elements.length}"
        sub =
          @elements
            .filter (x) => opts.extended or x.parent is this
            .reduce ((a,b) ->
              for k, v of b.toJSON()
                if a[k] instanceof Object
                  a[k][kk] = vv for kk, vv of v if v instanceof Object
                else
                  a[k] = v
              return a
            ), {}
        if opts.tag
          "#{@kind}": switch
            when Object.keys(sub).length > 0
              if @tag? then "#{@tag}": sub else sub
            when @tag instanceof Object then "#{@tag}"
            else @tag
        else sub

## Export Element Class

    module.exports = Element
