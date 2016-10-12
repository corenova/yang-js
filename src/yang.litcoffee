# Yang - evaluable schema expression

This module provides support for basic set of YANG schema modeling
language by using the built-in *extension* syntax to define additional
schema language constructs. The actual YANG language [RFC
6020](http://tools.ietf.org/html/rfc6020) specifications are loaded
inside the [main module](./main.coffee).

This module is the **primary interface** for consumers of this
library.

## Dependencies
 
    debug  = require('debug')('yang:schema') if process.env.DEBUG?
    fs     = require 'fs'
    path   = require 'path'
    parser = require 'yang-parser'
    indent = require 'indent-string'

    Expression = require './expression'

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

      @parse: (schema, compile=true) ->
        try
          schema = parser.parse schema if typeof schema is 'string'
        catch e
          e.offset = 50 unless e.offset > 50
          offender = schema.slice e.offset-50, e.offset+50
          offender = offender.replace /\s\s+/g, ' '
          throw @error "invalid YANG syntax detected", offender

        unless schema instanceof Object
          throw @error "must pass in valid YANG schema", schema

        kind = switch
          when !!schema.prf then "#{schema.prf}:#{schema.kw}"
          else schema.kw
        tag = schema.arg if !!schema.arg
		
        schema = (new this kind, tag).extends schema.substmts.map (x) => @parse x, false
        # perform final scoped constraint validation
        for kind, constraint of schema.scope when constraint in [ '1', '1..n' ]
          unless schema.hasOwnProperty kind
            throw schema.error "constraint violation for required '#{kind}' = #{constraint}"
        schema.compile() if compile
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
        # explict compose
        if opts.kind?
          ext = Yang::lookup.call this, 'extension', opts.kind
          unless ext instanceof Expression
            throw new Error "unable to find requested '#{opts.kind}' extension"
          return ext.compose? data, opts

        # implicit compose (dynamic discovery)
        for ext in @extension when ext.compose instanceof Function
          debug? "checking data if #{ext.tag}"
          res = ext.compose data, opts
          return res if res instanceof Yang

This facility is a powerful construct to dynamically generate `Yang`
schema from ordinary JS objects. For additional usage examples, please
refer to [Dynamic Composition](../TUTORIAL.md#dynamic-composition)
section in the [Getting Started Guide](../TUTORIAL.md).

### resolve (from..., name)

This call is internally used by [import](#import-name-opts) to
perform a search within the local filesystem to locate a given YANG
schema module by `name`. It will first check the calling code's local
[package.json](../package.json) to look for a `models: {}`
configuration section to identify where the target module can be
found. If there is an entry defined, it will then follow that
reference - which may be a JS file, YANG schema text file, or another
NPM module. If it is not found within the `models: {}` configuration
block or it fails to load the referenced dependency, it will then
fallback to attempt to locate a YANG schema text file in the same
folder that the `resolve` request was made: `#{name}.yang`.

      @resolve: (from..., name) ->
        return null unless typeof name is 'string'
        dir = from = switch
          when from.length then from[0]
          else path.resolve()
        while not found? and dir not in [ '/', '.' ]
          target = "#{dir}/package.json"
          debug? "[resolve] #{name} in #{target}"
          try
            pkginfo = require(target)
            found = pkginfo.models[name]
            dir = path.dirname require.resolve(target)
            debug? "[resolve] #{name} check #{found} in #{dir}"
            unless !!path.extname found
              from = switch
                when found of pkginfo.dependencies
                  path.resolve dir, 'node_modules', found
                else path.resolve dir, found
              if fs.existsSync from
                return @resolve from, name
              found = undefined
          dir = path.dirname dir unless found?
        file = switch
          when not found? then path.resolve from, "#{name}.yang"
          else path.resolve dir, found
        debug? "[resolve] checking if #{file} exists"
        return if fs.existsSync file then file else null

### import (name [, opts={}])

This call provides a convenience mechanism for dealing with YANG
schema module dependencies. It performs parsing of the YANG schema
content from the specified `name` and saves the generated `Yang`
expression inside the internal registry. The `name` can be a YANG
module name or a *filename* to the actual schema content (JS or YANG).

Once a given YANG module has been saved inside the registry,
subsequent [parse](#parse-schema) of YANG schema that *import* the
saved module will successfully resolve.

Typical usage scenario for this pattern is to internally define common
modules such as `ietf-yang-types` which can then be *imported* by
other schemas.

It will also return the new `Yang` expression instance (to do with as
you please).

      @require: ->
        console.warn "DEPRECATION: please use .import() instead"
        @import arguments...

      @import: (name, opts={}) ->
        return unless name?
        opts.basedir ?= ''
        opts.resolve ?= true
        extname  = path.extname name
        filename = path.resolve opts.basedir, name
        basedir  = path.dirname filename

        unless !!extname
          return (Yang::match.call this, 'module', name) ? @import (@resolve name), opts

        return require filename unless extname is '.yang'

        try return @use (@parse (fs.readFileSync filename, 'utf-8'), opts.resolve)
        catch e
          unless opts.resolve and e.name is 'ExpressionError' and e.context.kind in [ 'include', 'import' ]
            console.error "unable to require YANG module from '#{filename}'"
            console.error e
            throw e
          opts.resolve = false if e.context.kind is 'include'

          # try to find the dependency module for import
          dependency = @import (@resolve basedir, e.context.tag), opts
          unless dependency?
            e.message = "unable to auto-resolve '#{e.context.tag}' dependency module"
            throw e

          # retry the original request
          debug? "retrying import(#{name})"
          return @import arguments...

Please note that this method will look for the `name` in current
working directory of the script execution if the `name` is a relative
path. It utilizes the [resolve](#resolve-from-name) method and will
attempt to **recursively** resolve any failed `import` dependencies.

While this is a convenient abstraction, it is **recommended** to
directly use the Node.js built-in `require` mechanism (if
available). Using native `require` instead of `Yang.import` will
allow package bundlers such as `browserify` to capture the
dependencies as part of the produced bundle.  It also allows you to
directly load YANG schema files from other NPM modules.

By default, loading the [yang-js](./main.coffee) module will attempt
to associate `.yang` extension inside `require` facility. If
available, it will allow you to `require('./some-dependency.yang')`
and get back a parsed `Yang expression` instance.

## Main constructor

This method can be called directly without the use of `new` keyword
and will internally parse the provided schema and return a `bound
function` which will invoke [eval](#eval-data-opts) when called.

      constructor: (kind, tag, extension) ->
        unless @constructor is Yang
          return (-> @eval arguments...).bind (Yang.parse arguments[0], true)

        extension ?= (@lookup 'extension', kind)
        super kind, tag, extension
        unless extension instanceof Expression
          # see if custom extension
          @once 'compile:before', =>
            extension = (@lookup 'extension', kind)
            unless extension instanceof Yang
              throw @error "encountered unknown extension '#{kind}'"
            { @source, @argument } = extension

      @property 'datakey',
        get: -> switch
          when @parent instanceof Yang and @parent.kind is 'module' then "#{@parent.tag}:#{@tag}"
          else @tag ? @kind

      @property 'datapath',
        get: -> switch
          when @parent not instanceof Yang then ''
          when @node then @parent.datapath + "/#{@datakey}"
          else @parent.datapath
          
      error: (msg, context) -> super "[#{@trail}] #{msg}", context
      emit: (event, args...) ->
        @emitter.emit arguments...
        @root.emit event, this if event is 'change' and this isnt @root

## Instance-level methods

### bind (obj)

Every instance of `Yang` expression can be *bound* with control logic
which will be used during [eval](#eval-data-opts) to produce schema
infused **adaptive data object**. This routine is *inherited* from
[Class Expression](./core/expression.coffee).

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

      eval: (data, opts={}) ->
        if opts.adaptive is true
          # TODO: this will break for 'module' which will return Model?
          @once 'change', arguments.callee.bind(this, data, opts)
        super

Please refer to [Working with Models](../TUTORIAL.md#working-with-models)
section of the [Getting Started Guide](../TUTORIAL.md) for special
usage examples for `module` schemas.

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

### locate (ypath)

This is an internal helper facility used to locate a given schema node
within the `Yang` schema expression tree hierarchy. It supports a
limited version of XPATH-like expression to locate an explicit
element.

      locate: (ypath) ->
        # TODO: figure out how to eliminate duplicate code-block section
        # shared with Element
        return unless typeof ypath is 'string'
        ypath = ypath.replace /\s/g, ''
        if (/^\//.test ypath) and this isnt @root
          return @root.locate ypath
        [ key, rest... ] = ypath.split('/').filter (e) -> !!e
        return this unless key? and key isnt '.'

        if key is '..'
          return @parent?.locate rest.join('/')

        match = key.match /^([\._-\w]+):([\._-\w]+)$/
        return super unless match?

        [ prefix, target ] = [ match[1], match[2] ]
        debug? "[#{@trail}] locate looking for '#{prefix}:#{target}'"

        rest = rest.map (x) -> x.replace "#{prefix}:", ''
        skey = [target].concat(rest).join '/'

        if (@tag is prefix) or (@lookup 'prefix', prefix)
          debug? "[#{@trail}] (local) locate '#{skey}'"
          return super skey
        
        for m in @import ? [] when m.prefix.tag is prefix
          debug? "[#{@trail}] (external) locate #{skey}"
          return m.module.locate skey

        return undefined

### match (kind, tag)

This is an internal helper facility used by [locate](#locate-ypath) to
test whether a given entity exists in the local schema tree.

      # Yang Expression can support 'tag' with prefix to another module
      # (or itself).
      match: (kind, tag) ->
        return super unless kind? and tag? and typeof tag is 'string'
        [ prefix..., arg ] = tag.split ':'
        return super unless prefix.length

        prefix = prefix[0]
        # check if current module's prefix
        if @root?.prefix?.tag is prefix
          return @root.match kind, arg

        # check if submodule's parent prefix
        ctx = @lookup 'belongs-to'
        return ctx.module.match kind, arg if ctx?.prefix.tag is prefix

        # check if one of current module's imports
        imports = @root?.import ? []
        for m in imports when m.prefix.tag is prefix
          return m.module.match kind, arg

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
