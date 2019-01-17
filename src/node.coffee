debug = require('debug')('yang:node') if process.env.DEBUG?
path = require 'path'
fs = require 'fs'

{ Yang, Store, Model, Property } = require '.'

# initialize with YANG 1.1 extensions and typedefs
Yang.use require('./lang/extensions')
Yang.use require('./lang/typedefs')

# expose key class entities
Yang.Store = Store;
Yang.Model = Model;
Yang.Property = Property;

### Yang.import (name [, opts={}])

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

###

Yang.import = (name, opts={}) ->
  return unless name?
  opts.basedir ?= ''
  extname  = path.extname name
  filename = path.resolve opts.basedir, name
  basedir  = path.dirname filename

  unless !!extname
    return (Yang::match.call this, 'module', name) ? @import (@resolve name), opts

  unless extname is '.yang'
    res = require filename
    unless res instanceof Yang
      throw @error "unable to import '#{name}' from '#{filename}' (not Yang expression)", res
    return res 

  try return @use (@parse (fs.readFileSync filename, 'utf-8'), opts)
  catch e
    context = e
    debug? e
    unless opts.compile and e.name is 'ExpressionError' and context.kind in [ 'include', 'import' ]
      console.error "unable to parse '#{name}' YANG module from '#{filename}'"
      throw e
    if context.kind is 'include'
      opts = Object.assign {}, opts
      opts.compile = false 

    # try to find the dependency module for import
    dependency = @import (@resolve basedir, context.tag), opts
    unless dependency?
      e.message = "unable to auto-resolve '#{context.tag}' dependency module from '#{filename}'"
      throw e
    unless dependency.tag is context.tag
      e.message = "found mismatching module '#{dependency.tag}' while resolving '#{context.tag}'"
      throw e

    # retry the original request
    debug? "retrying import(#{name})"
    return @import arguments...

# automatically register if require.extensions available
require.extensions?['.yang'] ?= (m, filename) ->
  m.exports = Yang.import filename

module.exports = Yang
