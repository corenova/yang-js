P = require './operator'

identifier =
  P.variable.bind (v) ->
    (P.alphanum.orElse P.oneOf ':.-').concat().bind (rest) ->
      P.unit v + rest

expr = (func) -> term(func).bind (t) ->
  (P.or.bind -> expr(func)).option(false).bind (e) ->
    P.unit Boolean (t or e)

term = (func) -> factor(func).bind (f) ->
  (P.and.bind -> term(func)).option(true).bind (t) ->
    P.unit Boolean (f and t)

# whitespace permitted before or after any expression
factor = (func) ->
  P.choice(
    P.not.bind -> factor(func).bind (f) ->
      P.unit not f
    P.char('(').bind ->
      P.optSep.bind -> expr(func).bind (e) -> P.optSep.bind ->
        P.char(')').bind -> P.unit e
    identifier.bind (kw) ->
      P.unit (func? kw)        
  )

module.exports =
  bool: (text, resolver=->) ->
    expr(resolver).between(P.optSep, P.optSep).parse text
