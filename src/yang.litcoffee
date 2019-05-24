# Yang - evaluable schema expression

This module provides support for basic set of YANG schema modeling
language by using the built-in *extension* syntax to define additional
schema language constructs. The actual YANG language [RFC
6020](http://tools.ietf.org/html/rfc6020) specifications are loaded
inside the [main module](./main.coffee).

This module is the **primary interface** for consumers of this
library.

## Dependencies
 
    debug  = require('debug')('yang:schema')
    fs     = require 'fs'
    path   = require 'path'
    parser = require 'yang-parser'
    indent = require 'indent-string'

    Expression = require './expression'
    XPath = require './xpath'

## Class Yang

    class Yang extends Expression
      @scope:
        extension: '0..n'
        typedef:   '0..n'
        module:    '0..n'
        submodule: '0..n'

## Class-level methods

      @clear: ->
        @module.splice(0,@module.length) if @module?
        @submodule.splice(0,@submodule.length) if @submodule?

### parse (schema)

This class-level routine performs recursive parsing of passed in
statement and sub-statements. It provides syntactic, semantic and
contextual validations on the provided schema and returns the final JS
object tree structure as hierarchical Yang expression instances.

If any validation errors are encountered, it will throw the
appropriate error along with the context information regarding the
error.

      @parse: (schema, opts={}) ->
        opts.compile ?= true
        try
          schema = parser.parse schema if typeof schema is 'string'
        catch e
          e.offset = 50 unless e.offset > 50
          offender = schema.slice e.offset-50, e.offset+50
          offender = offender.replace /\s\s+/g, ' '
          throw @error "invalid YANG syntax detected around: '#{offender}'", offender

        unless schema instanceof Object
          throw @error "must pass in valid YANG schema", schema

        kind = switch
          when !!schema.prf then "#{schema.prf}:#{schema.kw}"
          else schema.kw
        tag = schema.arg unless schema.arg is false
		
        schema = (new this kind, tag).extends schema.substmts.map (x) => @parse x, compile: false
        # perform final scoped constraint validation
        for kind, constraint of schema.scope when constraint in [ '1', '1..n' ]
          unless schema.hasOwnProperty kind
            throw schema.error "constraint violation for required '#{kind}' = #{constraint}"
        schema.compile() if opts.compile
        return schema

For comprehensive overview on currently supported YANG statements,
please refer to
[Compliance Report](../test/yang-compliance-coverage.md) for the latest
[RFC 6020](http://tools.ietf.org/html/rfc6020) YANG specification
compliance.

### compose (data [, opts={}])

This call *accepts* any arbitrary JS object and it will attempt to
convert it into a structural `Yang` expression instance. It will
analyze the passed in JS data and perform best match mapping to an
appropriate YANG schema representation to describe the input
data. This method will not be able to determine conditionals or any
meta-data to further constrain the data, but it should provide a good
starting point with the resulting `Yang` expression instance.

      @compose: (data, opts={}) ->
        unless data?
          throw @error "must supply input 'data' to compose"

        # explict compose
        if opts.kind?
          ext = Yang::lookup.call this, 'extension', opts.kind
          unless ext instanceof Expression
            throw @error "unable to find requested '#{opts.kind}' extension"
          return ext.compose? data, opts

        # implicit compose (dynamic discovery)
        for ext in @extension when ext.compose instanceof Function
          debug "checking data if #{ext.tag}"
          res = ext.compose data, opts
          return res if res instanceof Yang

This facility is a powerful construct to dynamically generate `Yang`
schema from ordinary JS objects. For additional usage examples, please
refer to [Dynamic Composition](../TUTORIAL.md#dynamic-composition)
section in the [Getting Started Guide](../TUTORIAL.md).

### resolve (from..., name)

This call is used to perform a search within the local filesystem to
locate a given YANG schema module by `name`. It will first check the
calling code's local [package.json](../package.json) to look for a
`yang: { resolve: {} }` configuration section to identify where the
target module can be found. If there is an entry defined, it will then
follow that reference - which may be a JS file, YANG schema text file,
or another NPM module. If it is not found within the `yang: { resolve:
{} }` configuration block or it fails to load the referenced
dependency, it will then fallback to attempt to locate a YANG schema
text file in the same folder that the `resolve` request was made:
`#{name}.yang`.

      @resolve: (from..., name) ->
        return null unless typeof name is 'string'
        dir = from = switch
          when from.length then from[0]
          else path.resolve()
        while not found? and dir != path.dirname dir
          target = path.resolve dir, "package.json"
          debug "[resolve] #{name} in #{target}"
          try
            pkginfo = JSON.parse(fs.readFileSync(target))
            found = pkginfo.yang?.resolve?[name] ? pkginfo.models[name]
          if found?
            dir = path.dirname target
            debug "[resolve] #{name} check #{found} in #{dir}"
            unless !!path.extname found
              from = null
              if (found of (pkginfo.dependencies ? {})) or (found of (pkginfo.peerDependencies ? {}))
                # due to npm changes, the dependency may be at
                # higher in the directory tree instead of being at
                # subdirectory
                debug "[resolve] check #{found} package for #{name}"
                pkgdir = dir
                while not from? and pkgdir != path.dirname pkgdir
                  pkgloc = path.resolve(pkgdir, 'node_modules', found)
                  debug "[resolve] look for #{found} package in #{pkgloc}"
                  if fs.existsSync pkgloc
                    from = pkgloc
                  pkgdir = path.dirname pkgdir unless from?
              else
                from = path.resolve dir, found
              if fs.existsSync from
                return @resolve from, name
              else
                found = @resolve found, name
          if not found? and pkginfo?.name is name
            found = path.dirname target
          dir = path.dirname dir unless found?
        file = switch
          when not found? then path.resolve from, "#{name}.yang"
          else path.resolve dir, found
        debug "[resolve] checking if #{file} exists"
        return if fs.existsSync file then file else null

## Main constructor

This method can be called directly without the use of `new` keyword
and will internally parse the provided schema and return a `bound
function` which will invoke [eval](#eval-data-opts) when called.

      constructor: (kind, tag, extension) ->
        unless this instanceof Yang
          [ schema, bindings ] = arguments
          schema = Yang.parse schema unless schema instanceof Yang
          return schema.bind bindings

        extension ?= (@lookup 'extension', kind)
        self = super kind, tag, extension
        unless extension instanceof Expression
          @debug "defer processing of custom extension #{kind}"
          @once 'compile:before', (->
            @debug "processing deferred extension #{kind}"
            extension = (@lookup 'extension', kind)
            unless extension instanceof Yang
              throw @error "encountered unknown extension '#{kind}'"
            { @source, @argument } = extension
            extension.once 'bind', =>
              { @source, @argument } = extension
              @parent._cache = null
          ).bind self
        return self
        
      @property 'datakey',
        get: -> switch
          when @parent instanceof Yang and @parent.kind is 'module'
            "#{@parent.tag}:#{@tag}"
          when @parent instanceof Yang and @parent.kind is 'submodule'
            "#{@parent['belongs-to'].tag}:#{@tag}"
          when @node and @external and not @state.relative
            "#{@origin.root.tag}:#{@tag}"
          else @tag ? @kind

      @property 'external',
        get: -> @origin? and @origin.root isnt @root and @origin.root.kind is 'module'
            
      @property 'datapath',
        get: -> switch
          when @parent not instanceof Yang then ''
          when @node then @parent.datapath + "/#{@datakey}"
          else @parent.datapath + "/#{@kind}(#{@datakey})"
                  
      debug: -> debug "[#{@uri}]", arguments...
      emit: (event, args...) ->
        @emitter.emit arguments...
        @root.emit event, this if event is 'change' and this isnt @root

## Instance-level methods

### bind (obj)

Every instance of `Yang` expression can be *bound* with control logic
which will be used during [eval](#eval-data-opts) to produce schema
infused **adaptive data object**. This routine is *inherited* from
[Class Expression](./expression.coffee).

This facility can be used to associate default behaviors for any
element in the configuration tree, as well as handler logic for
various YANG statements such as *rpc*, *feature*, etc.

This call will return the original `Yang` expression instance with the
new bindings registered within the `Yang` expression hierarchy.

      # bind() is inherited from Expression

Please refer to [Schema Binding](../TUTORIAL.md#schema-binding)
section of the [Getting Started Guide](../TUTORIAL.md) for usage
examples.

### eval (data, opts={})

Every instance of `Yang` expression can be [eval](#eval-data-opts)
with arbitrary JS data input which will apply the schema against the
provided data and return a schema infused **adaptive** data object.

This is an extremely useful construct which brings out the true power
of YANG for defining and governing arbitrary JS data structures.

Basically, the input `data` will be YANG schema validated and
converted to a schema infused *adaptive data model* that dynamically
defines properties according to the schema expressions.

It currently supports the `opts.adaptive` parameter (default `false`)
which establishes a persistent binding relationship with the governing
`Yang` expression instance. This allows the generated model to
dynamically **adapt** to any changes to the governing `Yang`
expression instance. Refer to below [extends](#extends-schema) section
for additional info on how the schema can be programmatically
modified.

      eval: (data, ctx, opts={}) ->
        if opts.adaptive is true
          # TODO: this will break for 'module' which will return Model?
          @once 'change', arguments.callee.bind(this, data, opts)
        super

Please refer to [Working with Models](../TUTORIAL.md#working-with-models)
section of the [Getting Started Guide](../TUTORIAL.md) for special
usage examples for `module` schemas.

### validate (data, opts={})

Perform schema correctness validation for the passed in `data`.  This
differs from [eval](#eval-data-opts) in that the final data returned
is not infused as dynamic data model using Property instances. It
should be used to perform a sanity check on the data if it will not
be programmatically modified.

For example, [Property](./property.litcoffee) instance uses `validate`
when dealing with non-configurable data nodes `config false`. 

      validate: (data, ctx={}) ->
        # XXX - for now, we just do the full apply...
        return @apply data, ctx
        
        @compile() unless @resolved
        @debug "validating data to schema"

        try @predicate?.call this, data
        catch e
          throw @error "predicate validation error: #{e}", data

        if @kind is 'list' and Array.isArray data
          data = data.map (item) =>
            if Array.isArray item
              throw @error "list item cannot be another array"
            @validate item
        else
          # TODO: consider appending '..' property here?
          data[node.datakey] = node.validate data[node.datakey] for node in @nodes when data?

        unless @nodes.length
          data = this.apply data, ctx
        else
          data = attr.apply data, ctx for attr in @attrs
          
        return data

### extends (schema...)

Every instance of `Yang` expression can be `extends` with additional
YANG schema string(s) and it will automatically perform
[parse](#parse-schema) of the provided schema text and update itself
accordingly.

This action also triggers an event emitter which will *retroactively*
adapt any previously [eval](#eval-data-opts) produced adaptive data
model instances to react accordingly to the newly changed underlying
schema expression(s).

      # extends() is inherited from Element

      merge: (elem) ->
        unless elem instanceof Yang
          throw @error "cannot merge invalid element into Yang", elem

        switch elem.kind
          when 'type'     then super elem, append: true
          when 'argument' then super elem, replace: true
          else super

Please refer to [Schema Extension](../TUTORIAL.md#schema-extension)
section of the [Getting Started Guide](../TUTORIAL.md) for usage
examples.

      normalizePath: (ypath) ->
        lastPrefix = null
        prefix2module = (root, prefix) ->
          return unless root.kind is 'module'
          switch
            when root.tag is prefix then prefix
            when root.prefix.tag is prefix then root.tag
            else
              for m in root.import ? [] when m.tag is prefix or m.prefix.tag is prefix
                return m.tag
              modules = root.lookup 'module'
              for m in modules when m.tag is prefix or m.prefix.tag is prefix
                return m.tag
              return prefix # return as-is...
              
        normalizeEntry = (x) =>
          return x unless x? and !!x
          match = x.match /^(?:([._-\w]+):)?([.{[<\w][.,+_\-}():>\]\w]*)(?:\[.+\])?$/
          unless match?
            throw @error "invalid path expression '#{x}' found in #{ypath}"
          [ prefix, target ] = [ match[1], match[2] ]
          return switch
            when not prefix? then target
            when prefix is lastPrefix then target
            else
              lastPrefix = prefix
              mname = prefix2module @root, prefix
              "#{mname}:#{target}"
        ypath = ypath.replace /\s/g, ''
        res = XPath.split(ypath).map(normalizeEntry).join('/')
        res = '/' + res if /^\//.test ypath
        return res

### locate (ypath)

This is an internal helper facility used to locate a given schema node
within the `Yang` schema expression tree hierarchy. It supports a
limited version of XPATH-like expression to locate an explicit
element.

      locate: (ypath) ->
        # TODO: figure out how to eliminate duplicate code-block section
        # shared with Element
        return unless ypath?
        
        @debug "locate enter for '#{ypath}'"
        if typeof ypath is 'string'
          if (/^\//.test ypath) and this isnt @root
            return @root.locate ypath
          [ key, rest... ] = @normalizePath(ypath).split('/').filter (e) -> !!e
        else
          [ key, rest... ] = ypath
        @debug key
        return this unless key? and key isnt '.'

        if key is '..'
          return @parent?.locate rest

        match = key.match /^(?:([._-\w]+):)?([.{[<\w][.,+_\-}():>\]\w]*)$/
        [ prefix, target ] = [ match[1], match[2] ]
        if prefix? and this is @root
          search = [target].concat(rest)
          if (@tag is prefix) or (@lookup 'prefix', prefix)
            @debug "locate (local) '/#{prefix}:#{search.join('/')}'"
            return super search
          for m in @import ? [] when m.tag is prefix or m.prefix.tag is prefix
            @debug "locate (external) '/#{prefix}:#{search.join('/')}'"
            return m.module.locate search
          m = @lookup 'module', prefix
          return m?.locate search

        @debug "checking #{target}"
        switch
          when /^{.+}$/.test(target)
            kind = 'grouping'
            tag  = target.replace /^{(.+)}$/, '$1'
          when /^\[.+\]$/.test(target)
            kind = 'feature'
            tag  = target.replace /^\[(.+)\]$/, '$1'
          when /^[^(]+\([^)]*\)$/.test(target)
            target = target.match /^([^(]+)\((.*)\)$/
            [ kind, tag ] = [ target[1], target[2] ]
            tag = undefined unless !!tag
          when /^\<.+\>$/.test(target)
            target = target.replace /^\<(.+)\>$/, '$1'
            [ kind..., tag ]  = target.split ':'
            [ tag, selector ] = tag.split '='
            kind = kind[0] if kind?.length
          else return super [key].concat rest
            
        @debug "matching #{kind} #{tag}"
        match = @match kind, tag
        return switch
          when rest.length is 0 then match
          when Array.isArray match then match.map((x) -> x.locate rest).filter(Boolean)
          else match?.locate rest

### match (kind, tag)

This is an internal helper facility used by [locate](#locate-ypath) and
[lookup](./element.litcoffee#lookup-kind-tag) to test whether a given
entity exists in the local schema tree.

      # Yang Expression can support 'tag' with prefix to another module
      # (or itself).
      match: (kind, tag) ->
        return super unless kind? and tag? and typeof tag is 'string'
        res = super
        return res if res?
        
        [ prefix..., arg ] = tag.split ':'
        return unless prefix.length

        @debug "[match] with #{kind} #{tag}"

        prefix = prefix[0]
        @debug "[match] check if current module's prefix"
        if @root.tag is prefix or @root.prefix?.tag is prefix
          return @root.match kind, arg

        @debug "[match] checking if submodule's parent"
        ctx = @lookup 'belongs-to'
        if ctx?.prefix.tag is prefix
          return ctx.module.match kind, arg 

        @debug "[match] check if one of current module's imports"
        imports = @root?.import ? []
        for m in imports when m.prefix.tag is prefix
          @debug "[match] checking #{m.module.tag}"
          return m.module.match kind, arg

        @debug "[match] check if one of available modules"
        module = @lookup 'module', prefix
        return module.match kind, arg if module?

### toString (opts={})

The current `Yang` expression will covert back to the equivalent YANG
schema text format.

At first glance, this may not seem like a useful facility since YANG
schema text is *generally known* before [parse](#parse-schema) but it
becomes highly relevant when you consider a given `Yang` expression
programatically changing via [extends](#extends-schema).

Currently it supports `space` parameter which can be used to specify
number of spaces to use for indenting YANG statement blocks.  It
defaults to **2** but when set to **0**, the generated output will
omit newlines and other spacing for a more compact YANG output.

      toString: (opts={ space: 2 }) ->
        s = @kind
        if @source.argument?
          s += ' ' + switch @source.argument
            when 'value' then "'#{@tag}'"
            when 'text'
              "\n" + (indent '"'+@tag+'"', ' ', opts.space)
            else @tag
        sub =
          @elements
            .filter (x) => x.parent is this
            .map (x) -> x.toString opts
            .join "\n"
        if !!sub
          s += " {\n" + (indent sub, ' ', opts.space) + "\n}"
        else
          s += ';'
        return s

### toJSON

The current `Yang` expression will convert into a simple JS object
format.

      # toJSON() is inherited from Element

### valueOf

The current 'Yang' expression will convert into a primitive form for
comparision purposes.

      valueOf: ->
        switch @source.argument
          when 'value','text' then @tag.valueOf()
          else this

Please refer to [Schema Conversion](../TUTORIAL.md#schema-conversion)
section of the [Getting Started Guide](../TUTORIAL.md) for usage
examples.

## Export Yang Class

    module.exports = Yang
