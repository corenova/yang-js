path       = require 'path'
operator   = require('../ext/parser').Parser
Expression = require './expression'

class Filter extends Expression

  constructor: (pattern='') ->
    unless (Number.isNaN (Number pattern)) or ((Number pattern) % 1) isnt 0
      expr = Number pattern
    else
      expr = operator.parse pattern
      
    super 'filter', expr,
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
      represent: pattern
      
  toString: -> @represent
        
class XPath extends Expression

  constructor: (pattern) ->
    unless typeof pattern is 'string'
      throw @error "must pass in 'pattern' as valid string"
    pattern = path.normalize(pattern)
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
        data = [ data ] unless data instanceof Array
        data = data.reduce ((a,b) ->
          b = [ b ] unless b instanceof Array
          a.concat (b.map (elem) ->
            return elem if key is '.'
            return unless elem instanceof Object
            switch
              when key is '..' then elem.__?.parent
              when key is '*'  then (v for own k, v of elem)
              when elem.hasOwnProperty(key) then elem[key]
              
              # special handling for YANG prefixed key
              when /.+?:.+/.test(key) and elem.__?.schema?
                expr  = elem.__.schema
                match = expr.locate key
                if match?.parent is expr
                  [ prefix, key ] = key.split ':'
                  elem[key]
                else elem[key]
          )...
        ), []
        data = data.filter (e) -> e?

        # 2. filter by predicate(s) and sub-expressions
        for expr in @expressions
          break unless data? and data.length > 0
          data = expr.eval data

        return data

    @extends (predicates.map (x) -> new Filter x)... if predicates.length > 0
    @extends new XPath (elements.join '/') if elements.length > 0

  toString: ->
    s = if @tag is '/' then '' else @tag
    if @filter?
      s += "[#{filter}]" for filter in @filter
    if @xpath?
      s += "/#{@xpath}"
    return s

exports = module.exports = XPath
exports.parse = (pattern) -> new XPath pattern
