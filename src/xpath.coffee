operator   = require('../ext/parser').Parser
Expression = require './expression'

class Filter extends Expression

  constructor: (@pattern='') ->
    unless (Number.isNaN (Number @pattern)) or ((Number @pattern) % 1) isnt 0
      expr = Number @pattern
    else
      expr = operator.parse @pattern
      
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

  constructor: (pattern) ->
    unless typeof pattern is 'string'
      throw @error "must pass in 'pattern' as valid string"
    elements = pattern.match /([^\/^\[]+(?:\[.+?\])*)/g
    unless elements? and elements.length > 0
      throw @error "unable to process '#{pattern}' (please check your input)"
      
    if /^\//.test pattern
      target = '/'
      predicates = []
    else
      [ target, predicates... ] = elements.shift().split /\[\s*(.+?)\s*\]/
      predicates = predicates.filter (x) -> !!x
    
    super 'xpath', target,
      argument: 'node'
      scope:
        filter: '0..n'
        xpath:  '0..1'
        
      construct: (data) ->
        return data unless data instanceof Object

        # 0. traverse to the root of the data (if supported)
        if @tag is '/'
          data = data.__.parent while data.__?.parent?
          key = '.'
        else
          key = @tag
          
        # 1. select all matching nodes
        unless data instanceof Array
          prop = data.__
          data = [ data ] 
        data = data.reduce ((a,b) ->
          unless b instanceof Array
            prop = b.__
            b = [ b ] 
          a.concat (b.map (elem) ->
            return elem if key is '.'
            return unless elem instanceof Object
            res = switch
              when key is '..' then elem.__?.parent
              when key is '*'  then (v for own k, v of elem)
              when elem.hasOwnProperty(key) then elem[key]
              # special handling for YANG prefixed key
              when /.+?:.+/.test(key) and elem.__?.schema?
                expr  = elem.__.schema
                match = expr.locate key
                if match?.parent is expr
                  elem[match.datakey]
                else elem[key]
              else
                for own k of elem when /.+?:.+/.test(k)
                  [ prefix, kw ] = k.split ':'
                  if kw is key
                    match = elem[k]
                    break;
                match
            prop = res.__ if res?.__?
            res
          )...
        ), []
        data = data.filter (e) -> e?

        # 2. filter by predicate(s) and sub-expressions
        for expr in @exprs
          break unless data? and data.length > 0
          data = expr.apply data
        unless data.hasOwnProperty '__'
          Object.defineProperty data, '__', value: prop
        return data

    @extends (predicates.map (x) -> new Filter x)... if predicates.length > 0
    @extends new XPath (elements.join '/') if elements.length > 0

  # TODO: enable filter comparison
  compare: (xpath, opts={ filter: false }) ->
    return false unless xpath?
    xpath = new XPath xpath unless xpath instanceof XPath
    @tag is xpath.tag and (not @xpath? or @xpath.compare xpath.xpath)

  toString: ->
    s = if @tag is '/' then '' else @tag
    if @filter?
      s += "[#{filter}]" for filter in @filter
    if @xpath?
      s += "/#{@xpath}"
    return s

exports = module.exports = XPath
exports.parse = (pattern) -> new XPath pattern
