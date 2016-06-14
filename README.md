# yang-js

YANG parser and compiler

This module provides YANG schema processing according to
[RFC 6020](http://tools.ietf.org/html/rfc6020) specifications.

  [![NPM Version][npm-image]][npm-url]
  [![NPM Downloads][downloads-image]][downloads-url]

Also refer to [Compliance Report](./test/yang-v1-compliance.md) for the latest
[RFC 6020](http://tools.ietf.org/html/rfc6020) YANG specification
compliance.

This software is brought to you by
[Corenova](http://www.corenova.com).  We'd love to hear your feedback.
Please feel free to reach me at <peter@corenova.com> anytime with
questions, suggestions, etc.

## Installation

```bash
$ npm install yang-js
```

### Changes from 0.13.x to 0.14.x

Please note that the latest `0.14.x` branch is *incompatible* with
prior `0.13.x` releases.

The API for utilizing this module has been greatly simplified and most
of the previously exposed API methods are no longer available (since
they've become rather unnecessary).


## API

Here's an example for using this module:

```js
var yang = require('yang-js');
var fs   = require('fs');

try {
  var jukebox = yang.parse(fs.readFileSync('./example/jukebox.yang','utf8'));
  // ... do things with jukebox

  // converts back to YANG schema
  console.log(jukebox.toString());
} catch (e) {
  console.log(e);
}
```

### parse (schema)

This call returns a new Yang Expression containing the parsed schema
object sub-expression(s). It will perform syntactic and semantic
parsing of the input YANG schema. If any validation errors are
encountered, it will throw the appropriate error along with the
context information regarding the error.

It accepts YANG string schema text.

```
module foo {
  description hello;
  container bar {
	leaf a { type string; }
	leaf b { type int8; }
  }
}
```

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
foo = yang.parse """
  module foo {
    description hello;
	container bar {
	  leaf a { type string; }
	  leaf b { type int8; }
	}
  }
  """
foo.
foo.set 'foo.bar', { a: 'hello', b: 100 }
foo.get 'foo.bar.b' # returns 100
```

You can also combine multiple schema statements into a singular
object. The compiler accepts any arbitray YANG statements (it doesn't
need to be contained in a *module* statement) so you can mix/match
different statements to produce the desired object.

```coffeescript
yang = require 'yang-js'
combine = yang.load( 
  'leaf a { type string; }'
  'leaf b { type int8; }'
  'container foo { leaf bar { type string; } }'
)
```

In fact, you can mix/match different formats of YANG schema expression
and get the desired object as you'd expect:

```coffeescript
yang = require 'yang-js'
combine = yang.load(
  'leaf a { type string; }'     # YANG
  'leaf: { b: { type: int8 } }' # YAML
  container: 
    foo: 
      leaf: bar: type: 'string' # native JS object
)
```

Many other interesting ways to combine and produce various
schema-driven objects for immediately consumption.

### use (schema...)

You can pass in various schema(s) for compiling and defining into the
active `Compiler` instance.

It accepts schema(s) in various formats: YANG, YAML, and JS object

Below example in coffeescript demonstrates simple use:

```coffeescript
yang = require 'yang-js'
Example = yang
  .use 'module example { leaf test { type string; } }'
  .resolve 'example'
ex = new Example { example: test: 'hi' }
```

Typical usage scenario for this pattern is to internally define common
modules such as `ietf-yang-types` which can then be *imported* by
other schemas without requiring it be passed in as part of the `load`
operation every time.

```coffeescript
works = yang.load 'module example2 { import example { prefix ex; } }'
```

You can also pass in additional YANG language specifications for
processing *extensions* and *typedefs*. Specifications that alter the
behavior of the generated output are processed using a new built-in
*extension* called `specification`.  For an example of how YANG v1.0
language processing is defined, take a look at [YANG v1
Specification](./yang-v1-lang.yaml).  It utilizes [Data
Synth](http://github.com/saintkepha/data-synth) library for generating
the JS class object hierarchy.

This call returns the updated compiler instance with new definitions
processed from the passed in schema(s). It can then be used to
load/compile additional schema(s) or `resolve` to retrieve the
generated outputs.

## Class: Yang (Expression)

### eval (data [, opts={}])

Every instance of Yang Expression can be `eval` with arbitrary JS data
input which will apply the schema against the provided data and return
a schema infused adaptive data object.

This is an extremely useful construct which brings out the true power
of YANG for defining and governing arbitrary JS data structures.

Here's an example:

```javascript
var ys = yang.parse('container foo { leaf a { type uint8; } }');
var obj = ys.eval({ foo: { a: 7 } });
// obj is { foo: [Getter/Setter] }
// obj.foo is { a: [Getter/Setter] }
// obj.foo.a is 7
```

Basically, the input `data` will be YANG schema validated and
converted to a newly schema infused adaptive data object that
dynamically defines properties that are schema expressed.

Also, it's not a one-time validation during `eval` but persistently
bound to the newly generated output object:

```javascript
var ys = yang.parse('container foo { leaf a { type uint8; } }');
var obj = ys.eval();
// below assignment attempt will throw a validation error
obj.foo = { a: 'hello' };
// Error: uint8 expects 'hello' to convert into a number
```

### extends (schema...)

Every instance of Yang Expression can be `extends` with additional
YANG schema string(s) and it will automatically perform `parse` of
the provided schema text and update itself accordingly.

This action also triggers an event emitter which will *retroactively*
adapt any previously `eval` produced adaptive data object instances to
react accordingly to the newly changed underlying schema
expression(s).

Here's an example:

```javascript
var ys = yang.parse('container foo { leaf a; }');
var obj = ys.eval({ foo: { a: 'bar' } });
// try assigning a new arbitrary property
obj.foo.b = 'hello';
console.log(obj.foo.b);
// returns: undefined (since not part of schema)
// extend the original ys expression
ys.extends('leaf b;')
obj.foo.b = 'hello';
console.log(obj.foo.b)
// returns: 'hello' (since now part of schema!)
```

### lookup (kind [, tag)

Used to retrieve internally available definitions (such as *grouping*)
from the context of the current Yang Expression.

### toString (opts={ space: 2 })

The current YANG Expression will covert back to the active YANG schema format.

Currently it supports `space` parameter which can be used to
specify number of spaces to use for indenting YANG statement blocks.
It defaults to **2** but when set to **0**, the generated output will
omit newlines and other spacing for a more compact YANG output.

You can pass in various `obj`, including direct results from `load`,
`compile`, and `parse`.  For the `preprocess` output, you can pass in
the *schema* property of the result.

Below example in coffeescript illustrates various use:

```coffescript
yang = require 'yang-js'
schema = """
  module foo {
    description hello;
	container bar {
	  leaf a { type string; }
	  leaf b { type int8; }
	}
  }
  """

a = yang.dump (yang.parse schema)
b = yang.dump (yang.preprocess a).schema
c = yang.dump (yang.compile b)
d = yang.dump (yang.load c)

console.log a
console.log b
console.log c
console.log d
```

## License
  [Apache 2.0](LICENSE)

[npm-image]: https://img.shields.io/npm/v/yang-js.svg
[npm-url]: https://npmjs.org/package/yang-js
[downloads-image]: https://img.shields.io/npm/dm/yang-js.svg
[downloads-url]: https://npmjs.org/package/yang-js
