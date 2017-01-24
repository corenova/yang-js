P = require('xparse').Parser

optSep = P.space.skipMany()

identifier =
  P.variable.bind (v) ->
    (P.alphanum.orElse P.oneOf ':.-').concat().bind (rest) ->
      P.unit v + rest

module.exports =
  'node-identifier': P.create -> identifier
  'if-feature-expr': P.create ->
    expr = -> P.union.step(term, expr)
    term = -> P.combine.step(factor, term)
    factor = -> P.choice(
      P.negate.bind (op) -> factor().bind (f) -> P.wrap op, f
      P.char('(').bind ->
        optSep.bind -> expr().bind (e) -> optSep.bind ->
          P.char(')').bind -> P.unit e
      identifier.bind (kw) -> P.wrap null, kw
    )
    return expr().within(optSep)
