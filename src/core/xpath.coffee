operator   = require('../../ext/parser').Parser
Expression = require './expression'

class Filter extends Expression

  constructor: (@pattern='') ->
    unless (Number.isNaN (Number @pattern)) or ((Number @pattern) % 1) isnt 0
      expr = Number @pattern
    else
      try
        expr = operator.parse @pattern
      catch e
        console.error "unable to parse '#{@pattern}'"
        throw e
      
    super 'filter', expr,
      argument: 'predicate'
      scope: {}
      construct: (data) ->
        return data unless data instanceof Array
        return data unless data.length > 0
        return data unless !!@tag
        
        data = switch
          when typeof @tag is 'number' then [ data[@tag-1] ]
          else data.filter (elem) =>
            try
              # TODO: expand support for XPATH built-in predicate functions
              @tag.evaluate @tag.variables().reduce ((a,b) ->
                a[b] = switch b
                  when 'key'     then -> elem['@key']
                  when 'current' then -> elem
                  else elem[b]
                return a
              ), {}
            catch then false
        return data
      
  toString: -> @pattern
        
class XPath extends Expression

  constructor: (pattern, schema) ->
    unless typeof pattern is 'string'
      throw @error "must pass in 'pattern' as valid string"
      
    elements = pattern.match /([^\/^\[]*(?:\[.+?\])*)/g
    elements ?= []
    elements = elements.filter (x) -> !!x
    
    if /^\//.test pattern
      target = '/'
      schema = schema.root if schema instanceof Expression
      predicates = []
    else
      unless elements.length > 0
        throw @error "unable to process '#{pattern}' (please check your input)"
      [ target, predicates... ] = elements.shift().split /\[\s*(.+?)\s*\]/
      unless target?
        throw @error "unable to process '#{pattern}' (missing axis)"
      predicates = predicates.filter (x) -> !!x
      if schema instanceof Expression
        unless schema.locate target
          unless schema.kind is 'list'
            throw @error "unable to locate '#{target}' inside schema: #{schema.kind} #{schema.tag}"
          predicates.unshift "key() = '#{target}'"
          target = '.'
        schema = schema.locate target
    
    super 'xpath', target,
      argument: 'node'
      node: true
      scope:
        filter: '0..n'
        xpath:  '0..1'
      construct: (data) -> @match data

    if schema instanceof Expression
      Object.defineProperty this, 'schema', value: schema

    @extends (predicates.map (x) -> new Filter x, schema)... if predicates.length > 0
    @extends elements.join('/') if elements.length > 0

    if @xpath?.tag is '.'
      # absorb sub XPATH into itself
      @extends @xpath.filter
      if @xpath.xpath?
        @xpath = @xpath.xpath
      else
        delete @xpath

  merge: (elem) -> super switch
    when elem instanceof Expression then elem
    else new XPath elem, @schema
      
  match: (data) ->
    return data unless data instanceof Object

    # 0. traverse to the root of the data (if supported)
    if @tag is '/'
      data = data.__.parent while data.__?.parent? and not data.__?.root
      key = '.'
    else
      key = @tag
      schema = @schema

    # 1. select all matching nodes
    props = []
    data = [ data ] unless data instanceof Array
    data = data.reduce ((a,b) ->
      b = [ b ] unless b instanceof Array
      a.concat (b.map (elem) ->
        return unless elem instanceof Object
        res = switch
          when key is '.'  then elem
          when key is '..' then elem.__?.parent
          when key is '*'  then (v for own k, v of elem)
          when elem.hasOwnProperty(key) then elem[key]
          # special handling for YANG prefixed key
          when /.+?:.+/.test(key) and schema? then elem[schema.datakey]
          else
            for own k of elem when /.+?:.+/.test(k)
              [ prefix, kw ] = k.split ':'
              if kw is key
                match = elem[k]
                break;
            match
        prop = switch
          when res?.__? then res.__
          when elem.hasOwnProperty(key) then elem.__props__?[key]
        props.push prop if prop?
        res
      )...
    ), []
    data = data.filter (e) -> e?

    # 2. filter by predicate(s) and sub-expressions
    for expr in @attrs
      break unless data.length
      data = expr.apply data

    if @xpath?
      data = @xpath.apply data if @xpath? and data.length
    else
      # 3. at the end of XPATH, collect and save 'props'
      if @filter?
        props = (data.map (x) -> x.__).filter (x) -> x?
      Object.defineProperty data, 'props', value: props
    return data

  # returns the XPATH instance found matching the `pattern`
  locate: (pattern) ->
    try
      pattern = new XPath pattern, @schema unless pattern instanceof XPath
      return unless @tag is pattern.tag
      return unless not pattern.filter? or "#{@filter}" is "#{pattern.filter}"
      switch
        when @xpath? and pattern.xpath? then @xpath.locate pattern.xpath
        when pattern.xpath? then undefined
        else this

  # trims the current XPATH expressions after matching `pattern`
  trim: (pattern) ->
    match = @locate pattern
    delete match.xpath if match?
    return this

  # returns the XPATH `pattern` that matches part or all of this XPATH instance
  contains: (patterns...) ->
    for pattern in patterns
      return pattern if @locate(pattern)?

  toString: ->
    s = if @tag is '/' then '' else @tag
    if @filter?
      s += "[#{filter}]" for filter in @filter
    if @xpath?
      s += "/#{@xpath}"
    return s

exports = module.exports = XPath
exports.parse = (pattern, schema) -> new XPath pattern, schema
