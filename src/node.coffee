debug = require('debug')('yang:node')
path = require 'path'
fs = require 'fs'

Yang = require './yang' # needed for Yang::match

resolvePackagePath = (base, target, name, pkginfo = {}) ->
  { dependencies = {}, peerDependencies = {} } = pkginfo
  if (target of dependencies) or (target of peerDependencies)
    debug "[resolve:#{name}] find #{target} package location"
    # due to npm changes, the dependency may be at higher in the
    # directory tree instead of being found inside subdirectory
    while base != path.dirname base # not at the root of filesystem
      pkgdir = path.resolve base, 'node_modules', target
      debug "[resolve:#{name}] look for #{target} package in #{pkgdir}"
      return pkgdir if fs.existsSync pkgdir
      base = path.dirname base

DEFAULT_SEARCH_ORDER = ['.js', '.yang']

scanDirectory = (dir, name, checked={}) ->
  dir = path.resolve dir
  return null if dir of checked
  checked[dir] = true
  debug "[resolve:#{name}] scanning #{dir} folder..."
  try
    source = path.resolve dir, "package.json"
    debug "[resolve:#{name}] try opening #{source} inside #{dir}"
    pkginfo = JSON.parse(fs.readFileSync(source))

  if pkginfo?
    { search = [], order, resolve } = pkginfo.yang if pkginfo.yang?
    target = resolve?[name] ? pkginfo.models?[name]
    if target?
      debug "[resolve:#{name}] check '#{target}' defined in #{pkginfo.name} package.json"
      unless !!path.extname target
        # target is not a filename, check if it's a package
        where = resolvePackagePath dir, target, name, pkginfo
        where ?= path.resolve dir, target # probably folder otherwise
        file = scanDirectory where, name, checked
      else
        # target is an explicit filename
        file = path.resolve dir, target
      return file if fs.existsSync file
      throw @error "unable to resolve (#{name}) using explicit target (#{target}) definition inside #{pkginfo.name} package.json"
    else if pkginfo.name is name
      # target is the package itself
      return path.dirname source

    # try using search target array
    for target in [].concat(search...)
      where = resolvePackagePath dir, target, name, pkginfo
      where ?= path.resolve dir, target
      file = scanDirectory where, name, checked
      return file if fs.existsSync file

  # we didn't find explicit match inside package.json or there wasn't one in the dir
  order ?= DEFAULT_SEARCH_ORDER;
  debug "[resolve:#{name}] scanning #{dir} folder using [#{order}] extension order..."
  for filename in ([].concat(order...).map (ext) -> "#{name}#{ext}")
    file = path.resolve dir, filename
    debug "[resolve:#{name}] checking for file #{file}..."
    return file if fs.existsSync file
  return null

YangNodeUtils = {
  
  ### resolve (from..., name)

  This call is used to perform a search within the local filesystem to
  locate a given YANG schema module by `name`.

  1. It will first check the calling code's local
  [package.json](../package.json) to look for a `yang: { resolve: {} }`
  configuration section to identify where the target module can be
  found.

  1a. If entry defined, it will then follow that
  reference - which may be a JS file, YANG schema text file, another
  NPM module or a directory.

  1b. If no entry defined, it will then check for `yang: { search: [] }`
  configuration section to perform directory search.

  If it is not found within the `yang: { resolve: {} }` configuration
  block or it fails to load the referenced dependency, it will then
  fallback to attempt to locate a YANG schema text file in the same
  folder that the `resolve` request was made: `#{name}.yang`.

  ###
  resolve: (search..., name) ->
    return null unless typeof name is 'string'
    # use current directory if called without search dirs
    search.push path.resolve() unless search.length
    checked = {} # keep track of already checked directories
    for dir in search
      dir = path.resolve dir
      while dir != path.dirname dir
        match = scanDirectory dir, name, checked
        if fs.existsSync match
          debug "[resolve:#{name}] found #{match}"
          return match 
        dir = path.dirname dir # go up a directory
    return null

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
  import: (name, opts={}) ->
    return unless name?
    opts.basedir ?= ''
    extname  = path.extname name
    filename = path.resolve opts.basedir, name
    basedir  = path.dirname filename

    debug "[import] trying #{name}..."
    unless !!extname
      return (Yang::match.call this, 'module', name) ? @import (@resolve name), opts

    unless extname is '.yang'
      res = require filename
      unless res instanceof Yang
        throw @error "unable to import '#{name}' from '#{filename}' (not Yang expression)", res
      return res 

    try return @use (@parse (fs.readFileSync filename, 'utf-8'), opts)
    catch e
      debug? e
      unless opts.compile and e.name is 'ExpressionError' and e.ctx.kind in [ 'include', 'import' ]
        console.error "unable to parse '#{name}' YANG module from '#{filename}'"
        throw e
      switch e.ctx.kind
        when 'import'
          throw e if e.ctx.module?
        when 'include'
          opts = Object.assign {}, opts
          opts.compile = false 

      # try to find the dependency module for import
      dependency = @import (@resolve basedir, e.ctx.tag), opts
      unless dependency?
        e.message = "unable to auto-resolve '#{e.ctx.tag}' dependency module from '#{filename}'"
        throw e
      unless dependency.tag is e.ctx.tag
        e.message = "found mismatching module '#{dependency.tag}' while resolving '#{e.ctx.tag}'"
        throw e

      # retry the original request
      debug "[import] retrying for #{name}..."
      return @import arguments...
}

module.exports = YangNodeUtils
