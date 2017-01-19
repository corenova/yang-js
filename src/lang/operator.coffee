P = require 'comparse'
debug = require('debug')('yang:operator')

sep = P.space.skipMany 1
optSep = P.space.skipMany()

class Operator extends P
  @sep = sep
  @optSep = optSep

  @number = P.char('-').option('').bind (neg) ->
    (P.digit.orElse P.char('.')).concat(1).bind (ds) ->
      P.unit Number (neg + ds)
  @variable = (P.letter.orElse P.char '_').bind (fst) ->
    P.alphanum.concat().bind (rest) ->
      P.unit fst + rest
  @quote = P.noneOf("'").concat().between P.char("'"),P.char("'")
  @argument = P.choice(@variable, @quote, @number).between optSep, optSep
  @function = @variable.bind (name) ->
    P.char('(').bind ->
      Operator.argument.option().bind (arg) ->
        P.char(')').bind ->
          P.unit [ name, arg ]

  @operators =
    '*': (x, y) -> x * y
    '/': (x, y) -> x / y
    '%': (x, y) -> x % y
    '+': (x, y) -> x + y
    '-': (x, y) -> x - y
    '<': (x, y) -> x < y
    '<=': (x, y) -> x <= y
    '>': (x, y) -> x > y
    '>=': (x, y) -> x >= y
    '=': (x, y) -> x == y
    '==': (x, y) -> x == y
    'div': (x, y) -> x / y
    'mod': (x, y) -> x % y

  @multiply = P.char('*')
  @divide = P.char('/').orElse P.string('div').between sep, sep
  @modulo = P.char('%').orElse P.string('mod').between sep, sep
  @plus = P.char('+')
  @minus = P.char('-')
  @lessThan = P.char('<')
  @lessThanEqual = P.string('<=')
  @greaterThan = P.char('>')
  @greaterThanEqual = P.string('>=')
  @equal = P.string('==').orElse P.char('=')
  @not = P.char('!').orElse P.string('not').between optSep, sep
  @or  = P.char('|').repeat(2).orElse P.string('or').between sep, sep
  @and = P.char('&').repeat(2).orElse P.string('and').between sep, sep

  @oper = P.choice(
    @multiply, @divide, @modulo, @plus, @minus
    @lessThan, @lessThanEqual,
    @greaterThan, @greaterThanEqual,
    @equal
  ).between(optSep, optSep).bind (op) => P.unit @operators[op]

exec = (x, y, z) ->
  debug arguments
  x = if typeof x is 'function' then x(z) else x
  y = if typeof y is 'function' then y(z) else y
  this?(x,y) ? z?(x,y)

expr = -> term().bind (t) ->
  debug "expr: #{t}"
  P.choice(
    Operator.oper.bind (op) -> expr().bind (e) ->
      debug "#{t} #{op.name} #{e}"
      P.unit exec.bind op, t, e
    (Operator.or.bind -> expr()).bind (e) ->
      func = (x, y) -> Boolean (x or y)
      P.unit exec.bind func, t, e
    P.unit t
  )

term = -> factor().bind (f) ->
  P.choice(
    (Operator.and.bind -> term()).bind (t) ->
      func = (x, y) -> Boolean (x and y)
      P.unit exec.bind func, f, t
    P.unit f
  )

factor = ->
  P.choice(
    Operator.not.bind -> factor().bind (f) ->
      func = (x) -> not x
      P.unit exec.bind func, f, null
    P.char('(').bind ->
      optSep.bind -> expr().bind (e) -> optSep.bind ->
        P.char(')').bind -> P.unit e
    Operator.function.bind (kv=[]) ->
      debug "function: #{kv}"
      [ name, arg ] = kv
      P.unit exec.bind null, name, arg
    Operator.variable.bind (v) ->
      debug "variable: #{v}"
      P.unit exec.bind null, v, null
    Operator.number
    Operator.quote
  )

parse = (text) ->
  f = expr().between(optSep, optSep).parse text
  return f if typeof f is 'function'
  -> f

module.exports = Operator
module.exports.eval = (text, resolver=->) -> parse(text)(resolver)
module.exports.parse = parse
