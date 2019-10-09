debug = require('debug')('yang:xpath') if process.env.DEBUG?
Expression = require './expression'
xparse = require 'xparse'
kProp = Symbol.for('property')

class Filter extends Expression

  constructor: (@pattern='') ->

    super 'filter', xparse(@pattern),
      argument: 'predicate'
      scope: {}
      transform: (prop) ->
        expr = @tag
        switch typeof expr
          when 'number' then prop.props[expr-1]
          when 'string' then prop.children.get("key(#{expr})")
          else
            props = switch
              when prop.kind is 'list' then prop.props
              else [ prop ]
            props.filter (prop) -> expr (name, arg) ->
              elem = prop.content
              return elem[name] unless arg?
              switch name
                when 'current' then elem
                when 'false'   then false
                when 'true'    then true
                when 'key'     then arg
                when 'name'    then elem[arg]

  clone: -> new @constructor @pattern
  toString: -> @pattern
        
class XPath extends Expression

  @split: (pattern) ->
    elements = pattern.match /([^\/^\[]*(?:\[.+?\])*)/g
    elements ?= []
    elements = elements.filter (x) -> !!x
    return elements
        
  constructor: (pattern, schema) ->
    return pattern if pattern instanceof XPath
    
    unless typeof pattern is 'string'
      throw @error "must pass in 'pattern' as valid string"

    elements = XPath.split(pattern)
    
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
        try match = schema.locate target
        catch e then console.warn e
        unless match? then switch schema.kind
          when 'list'
            predicates.unshift switch
              when schema.key? then "'#{target}'"
              else target
            target = '.'
          when 'anydata' then schema = undefined
          else
            throw @error "unable to locate '#{target}' inside schema: #{schema.uri}"
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

  @property 'tail',
    get: ->
      end = this
      end = end.xpath while end.xpath?
      return end

  process: (data) ->
    debug? "[#{@tag}] process using schema from #{@schema?.kind}:#{@schema?.tag}"
    return [] unless data instanceof Object

    # 1. find all matching props
    data = [].concat(data)
    data = data.reduce ((a, prop) => a.concat(@match(prop))), []
    return @xpath.eval data if @xpath? and data.length
    
    debug? "[#{@tag}] returning #{data.length} properties"
    debug? data
    return data

  match: (prop) ->
    # console.warn('MATCH', @tag, prop.children);
    result = switch
      when @tag is '/' then prop.root
      when @tag is '.' then prop
      when @tag is '..' then prop.parent
      when @tag is '*' then prop.props
      when prop.children.has(@tag) then prop.children.get(@tag)
      when prop.kind is 'list' then prop.props.map (li) => li.children.get(@tag)
      when @schema? then prop.children.get(@schema.datakey)
    result = [].concat(result).filter(Boolean);
    # console.warn('MATCH RESULT', result);
    
    # 2. filter by predicate(s) and sub-expressions
    if @filter?
      for expr in @filter
        break unless result.length
        result = result.reduce ((a, b) ->
          a.concat(expr.eval(b)).filter(Boolean)
        ), []
        
    return result
      
  clone: ->
    schema = if @tag is '/' then @schema else @parent?.schema
    (new @constructor @tag, schema).extends @exprs.map (x) -> x.clone()

  merge: (elem) ->
    elem = switch
      when elem instanceof Expression then elem
      else new XPath elem, @schema
    if elem.tag is '.'
      @extends elem.filter, elem.xpath
      return this
    else super elem

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

  # append a new pattern at the tail of the current XPATH expression
  append: (pattern) ->
    @tail.merge pattern
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
