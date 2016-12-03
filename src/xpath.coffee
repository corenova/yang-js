debug = require('debug')('yang:xpath') if process.env.DEBUG?
Expression = require './expression'
Operator   = require('../ext/parser').Parser

class Filter extends Expression

  constructor: (@pattern='') ->
    unless (Number.isNaN (Number @pattern)) or ((Number @pattern) % 1) isnt 0
      expr = Number @pattern
    else
      try expr = Operator.parse @pattern
      catch e
        console.error "unable to parse '#{@pattern}'"
        throw e

    unless !!expr
      throw @error "invalid predicate filter: [#{expr}]"
      
    super 'filter', expr,
      argument: 'predicate'
      scope: {}
      transform: (data) ->
        return data unless data instanceof Array
        return data unless data.length > 0
        debug? "filter: #{@tag}"
        if typeof @tag is 'number' then return [ data[@tag-1] ]
        data = data.filter (elem) =>
          # TODO: expand support for XPATH built-in predicate functions
          expr = @tag.variables().reduce ((a,b) ->
            a[b] = switch b
              when 'key'     then -> elem['@key']
              when 'current' then -> elem
              when 'false'   then -> false
              when 'true'    then -> true
              else elem[b]
            return a
          ), {}
          debug? expr
          try @tag.evaluate expr
          catch e then debug?(e); false
        return data

  clone: -> new @constructor @pattern
  toString: -> @pattern
        
class XPath extends Expression

  constructor: (pattern, schema) ->
    unless typeof pattern is 'string'
      throw @error "must pass in 'pattern' as valid string"

    debug? "[#{pattern}] constructing..."
      
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
        debug? "[#{pattern}] with #{schema.kind}(#{schema.tag})"
        try match = schema.locate target
        catch e then console.warn e
        unless match? then switch schema.kind
          when 'list'
            predicates.unshift switch
              when schema.key? then "key() = '#{target}'"
              else target
            target = '.'
          when 'anydata' then schema = undefined
          else
            throw @error "unable to locate '#{target}' inside schema: #{schema.trail}"
        else
          schema = match
          target = schema.datakey unless /^\./.test target
    
    super 'xpath', target,
      argument: 'node'
      scope:
        filter: '0..n'
        xpath:  '0..1'
      transform: (data) -> @process data

    if schema instanceof Expression
      Object.defineProperty this, 'schema', value: schema

    @extends (predicates.map (x) -> new Filter x)... if predicates.length > 0
    @extends elements.join('/') if elements.length > 0

    debug? "[#{pattern}] construction complete"

  clone: ->
    debug? "[#{@tag}] cloning..."
    schema = if @tag is '/' then @schema else @parent?.schema
    (new @constructor @tag, schema).extends @elements.map (x) -> x.clone()

  merge: (elem) ->
    elem = switch
      when elem instanceof Expression then elem
      else new XPath elem, @schema
    if elem.tag is '.'
      debug? "[merge] absorbing sub-XPATH into '#{@tag}'"
      @extends elem.filter, elem.xpath
      return this
    else super elem

  process: (data) ->
    debug? "[#{@tag}] process using schema from #{@schema?.kind}:#{@schema?.tag}"
    debug? data
    return [] unless data instanceof Object

    # 1. select all matching nodes
    props = []
    data = [ data ] unless data instanceof Array
    data = data.reduce ((a,b) =>
      b = [ b ] unless b instanceof Array
      a.concat (b.map (elem) => @match elem, props)...
    ), []
    data = data.filter (e) -> e?
    debug? "[#{@tag}] found #{data.length} matching nodes"
    debug? data

    # 2. filter by predicate(s) and sub-expressions
    if @filter?
      for expr in @filter
        break unless data.length
        data = expr.eval data

    if @xpath?
      # 3a. apply additional XPATH expressions
      debug? "apply additional XPATH expressions"
      data = @xpath.eval data if @xpath? and data.length
    else
      # 3b. at the end of XPATH, collect and save 'props'
      debug? "end of XPATH, collecting props"
      if @filter?
        props = (data.map (x) -> x.__).filter (x) -> x?
      debug? props
      Object.defineProperty data, 'props', value: props
    debug? "[#{@tag}] returning #{data.length} data with #{data.props?.length} properties"
    return data

  match: (item, props=[]) ->
    key = switch
      when @tag is '/' then '.'
      else @tag
        
    return unless item instanceof Object
    res = switch
      when key is '.'  then item
      when key is '..' then switch
        when item.__? and item.__.key? then item.__.parent.container
        when item.__? then item.__.container
      when key is '*'  then (v for own k, v of item)
      when item.hasOwnProperty(key) then item[key]
      
      # special handling for YANG schema defined XPATH
      when @schema instanceof Expression
        key = @schema.datakey
        item[key]
      # special handling for Property bound item
      when item.__?
        key = item.__.schema?.datakey
        item[key] if key?
          
    # extract Property instances (if available)
    switch
      when key is '*'      then res?.forEach (x) -> props.push x.__ if x.__?
      when res?.__?        then props.push res.__
      when item.__props__? then props.push item.__props__[key] if key of item.__props__
    return res
      
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

  # append a new pattern at the end of the current XPATH expression
  append: (pattern) ->
    end = this
    end = end.xpath while end.xpath?
    debug? "[#{@tag}] appending #{pattern} to #{end.tag}"
    end.merge pattern
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
    s = @tag if !s
    return s

exports = module.exports = XPath
exports.Filter = Filter
exports.parse = (pattern, schema) -> new XPath pattern, schema
