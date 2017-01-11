YANG Parser
===========

This is the CoffeeScript source of a parser for the
[YANG](http://tools.ietf.org/html/rfc7950 "RFC 7950") data modelling
language.

:exclamation: NOTE: The current implementation only parses
text snippets that follow the general YANG lexical structure and turns them into
JavaScript/CoffeeScript objects. Additional syntactic and semantic
validation will be implemented later.

The parser is based on the
[Comparse](https://www.npmjs.org/package/comparse) library.

    P = require('comparse')

First, we define a class for YANG statements. The instance variables
are:

* `prf`: prefix of the keyword (non-empty for extension keywords)

* `kw`: statement keyword

* `arg`: argument

* `substmts`: array of substatements

Class definition
----------------

    class YangStatement
      constructor: (@prf, @kw, @arg, @substmts) ->

Comments
--------

YANG allows two types of comments in C++ style. Line comments start
with `//` and extend to the end of line.

    lineComment =
      (P.string '//').bind ->
        P.anyChar.manyTill(P.char '\n').bind (cs) ->
          P.unit cs.join ''

Block comments are enclosed in `/*` and `*/`. They cannot be nested.

    blockComment =
      (P.string '/*').bind ->
        P.anyChar.manyTill(P.string '*/').bind (cs) ->
          P.unit cs.join ''
    
    comment = lineComment.orElse blockComment

Parsers should treat comments as equivalent to a single space
(RFC 7950,
[Sec. 14](http://tools.ietf.org/html/rfc7950#section-14)). Hence, we
define two scanners for separators, mandatory and optional, that
permit any combination of whitespace characters and comments.

    # Mandatory separator
    sep = (P.space.orElse comment).skipMany 1

    # Optional separator
    optSep = (P.space.orElse comment).skipMany()

Keywords
--------

Identifiers in YANG must start with a letter or underline (`_`), other
characters may also be numbers, dash (`-`) or period (`.`). As a
special exception, an identifier must not start with the string whose
lowercase version matches `xml`.

    identifier =
      (P.letter.orElse P.char '_').bind (fst) ->
        (P.alphanum.orElse P.oneOf '.-').many().bind (tail) ->
          res = fst + tail.join ''
          P.unit if res[..2].toLowerCase() is 'xml' then null else res

A keyword is normally an identifier such as `module` or
`container`. Keywords of extension statements (RFC 7950,
[Sec. 7.19](http://tools.ietf.org/html/rfc7950#section-7.19)) must
have a prefix separated from the statement name with a colon
(':'). Lexically, a prefix is also an identifier.

    keyword =
      (identifier.bind (prf) -> P.char(':').bind ->
        P.unit prf).option().bind (pon) ->
          identifier.bind (kw) ->
            P.unit [pon, kw]

Arguments
---------

By far, the most difficult task for a YANG lexer is the parsing of
arguments because they can be unquoted, single- or
double-quoted. Moreover, double-quoted strings also follow several
special rules. See
[Sec. 6.1.3](http://tools.ietf.org/html/rfc7950#section-6.1.3) of
RFC 7950 for details.

An unquoted argument must not contain whitespace, semicolon (`;`),
braces (`{` or `}`) and opening comment sequences (`//` or `/*`).

    uArg =
      (P.noneOf(" '\"\n\t\r;{}/").orElse \
        P.char('/').notFollowedBy(P.oneOf '/*')).concat(1)

Otherwise, an argument is a single- or double-quoted literal strings, or
multiple single- or double-quoted strings concatenated with `+`.

A single-quoted literal string is simple – it may contain arbitrary
characters except single quote (`'`). No escape sequences are possible.

    sqLit =
      P.sat((c) -> c != "'").concat().between(
        P.char("'"), P.char("'"))

A double-quoted string is considerably more complicated. First, it may
contain one of four escape sequences representing special characters.

    escape = P.char('\\').bind ->
      esc =
        't': '\t'
        'n': '\n'
        '"': '"'
        '\\': '\\'
      P.oneOf('tn"\\').bind((c) -> P.unit esc[c]).orElse fallback

However, earlier RFC was underspecified on the escape rules so we
allow for fallback of accepting any escape sequence unless we detect
that the module in question is explicitly 1.1 version.

    strict = false
    fallback = P.anyChar.bind (c) ->
      P.unit if strict then null else "\\#{c}"

Then, a double-quoted string may contain any character except double
quote (`"`) or backslash (`\`), or an escape sequence:

    dqChar = P.noneOf('"\\').orElse escape

A double-quoted literal string consisting of multiple lines is subject
to the following whitespace trimming rules:

* Spaces and tabs immediately preceding a newline character are
  removed.

* In the second and subsequent lines, the leading spaces and tabs are
  are removed up to and including the column of the opening double
  quote character in the first line, or to the first non-whitespace
  character, whichever comes first. In this process, a tab character
  is treated as 8 spaces.

So, upon encountering the opening double quote, we use the
predefined `coordinates` parser to find out the
column in which the double quote occurs.

    dqLit =
      P.char('"').bind -> P.coordinates.bind (col) ->
        dqString col[1]

Then we process the rest of the string up to the next unquoted `"`
character and perform whitespace trimming. The column of the opening
double quote is passed to the `dqString` in the `lim` argument.

    dqString = (lim) ->
      # This helper function trims the leading whitespace
      trimLead = (str) ->
        left = lim
        sptab = '        '
        i = 0
        while left > 0
          c = str[i++]
          if c == ' '
            left -= 1
          else if c == '\t'
            return sptab[...8-left] + str[i..] if left < 8
            left -= 8
          else
            return str[(i-1)..]
        str[i..]
      dqChar.manyTill(P.char '"').bind (cs) ->
        lines = cs.join('').split('\n')
        # all but first: trim leading whitespace 
        tlines = [lines[0]]
        for ln in lines[1..]
          tlines.push trimLead ln
        # all but last: trim trailing whitespace
        res = []
        for ln in tlines[..-2]
          mo = ln.match /(.*\S)?\s*/
          res.push mo[1]
        res.push tlines.pop()
        P.unit res.join('\n')
    
A quoted argument consists of one or more single- or double-quoted
literal strings concatenated using the operator `+` (which may be
surrounded by whitespace or comments).
    
    qArg = dqLit.orElse(sqLit).bind (lft) ->
      (P.char('+').between(optSep, optSep).bind -> qArg).option().bind (rt) ->
        P.unit lft + rt

All in all, an argument is unquoted or quoted.

    argument = uArg.orElse(qArg)

Statements
----------

Equipped with the above parsers, we can now easily define a recursive
parser for a YANG statement, which consists of a keyword, argument,
and then either a semicolon or a block of substatements. If an
argument is present, it must be separated from the keyword by
whitespace or comment. A separator preceding the semicolon or block is
optional.

The result of the `statement` parser is an initialized `YangStatement` object.

    statement = keyword.bind (kw) ->
      (sep.bind -> argument).option().bind (arg) ->
        strict = true if kw[1] is 'yang-version' and arg is '1.1'
        optSep.bind -> semiOrBlock.bind (sst) ->
          P.unit new YangStatement kw[0], kw[1], arg, sst

A statement block is a sequence of statements enclosed in
braces. Whitespace or comments are permitted before or after any
statement in the block.

    stmtBlock = P.char('{').bind ->
      (optSep.bind -> statement).manyTill optSep.bind -> P.char('}')
    
    semiOrBlock = (P.char(';').bind -> P.unit []).orElse stmtBlock

Parsing Function
----------------

The public API of this module consists of a single parsing
function named `parse`. It can parse either an entire YANG module or
just a single statement.

Its arguments are:

* `text`: text to parse,

* `top` (optional): keyword of the top-level statement. If it is not given or has the value of `null`, then any statement is accepted.

This function is installed in the `module.exports` object so that it
can be imported from other modules.

    parse = (text, top=null) ->
      yst = statement.between(optSep, optSep).parse text
      if top? and yst.kw != top
        throw P.error "Wrong top-level statement", 0
      yst
    
    module.exports = {parse}

