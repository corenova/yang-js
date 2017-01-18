P = require 'comparse'

identifier =
  (P.letter.orElse P.char '_').bind (fst) ->
    (P.alphanum.orElse P.oneOf '.-').many().bind (tail) ->
      P.unit fst + tail.join ''
sep = P.space.skipMany 1 # mandatory
optSep = P.space.skipMany()
notOper = P.char('!').orElse P.string('not')
orOper  = P.char('|').repeat(2).orElse P.string('or')
andOper = P.char('&').repeat(2).orElse P.string('and')

expr = (test) -> term(test).bind (t) ->
  (sep.bind -> orOper.bind -> sep.bind -> expr(test)).option(false).bind (e) ->
    P.unit t or e

term = (test) -> factor(test).bind (f) ->
  (sep.bind -> andOper.bind -> sep.bind -> term(test)).option(true).bind (t) ->
    P.unit f and t

# whitespace permitted before or after any expression
factor = (test) ->
  (notOper.bind -> sep.bind -> factor(test).bind (f) ->
    P.unit not f
  ).orElse (P.char('(').bind ->
    optSep.bind -> expr(test).bind (e) -> optSep.bind ->
      P.char(')').bind -> P.unit e
  ).orElse identifier.bind (kw) ->
    P.unit (test? kw)

module.exports =
  bool: (text, test) -> expr(test).parse text
