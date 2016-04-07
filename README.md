# yang-js

YANG parser and compiler

This module provides YANG schema processing according to
[RFC 6020](http://tools.ietf.org/html/rfc6020) specifications.

  [![NPM Version][npm-image]][npm-url]
  [![NPM Downloads][downloads-image]][downloads-url]

Also refer to [Coverage Report](./yang-v1-coverage.md) for the latest
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

For more advanced composition tooling take a look at these extension
modules:

name | description
--- | ---
[yang-cc](https://github.com/corenova/yang-cc) | YANG model-driven application core composer (useful for dealing with files across multiple directories)
[yang-forge](https://github.com/corenova/yang-forge) | YANG package manager and runtime engine (dynamic interface generators and build/publish)

## API

Here's an example for using this module:

```js
var yang = require('yang-js');
var fs   = require('fs');

try {
  var jukebox = yang.load(fs.readFileSync('./example/jukebox.yang','utf8'));
  // jukebox.set, jukebox.get, jukebox.invoke, etc.
  console.log(yang.dump(jukebox, { indent: 2 }));
} catch (e) {
  console.log(e);
}
```

### load (schema...)

*Suggested primary interface*

This call returns a new Yang object containing the compiled schema
object instance(s).

It accepts schema(s) in various formats: YANG, YAML, and JS object

```
# YANG foo module
module foo {
  description hello;
  container bar {
	leaf a { type string; }
	leaf b { type int8; }
  }
}

# YANG foo module expressed as YAML
module:
  foo:
    description: hello
    container:
      bar:
        leaf:
          a: { type: string }
          b: { type: int8 }
```

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
foo = yang.load """
  module foo {
    description hello;
	container bar {
	  leaf a { type string; }
	  leaf b { type int8; }
	}
  }
  """
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
# other ex.set, ex.get, ex.invoke operations
```

Typical usage scenario for this pattern is to internally define common
modules such as `ietf-yang-types` which can then be *imported* by
other schemas without requiring it be passed in as part of the `load`
operation every time.

```coffeescript
# this will internally resolve the 'example' module for import
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

### resolve (type [, key)

Used to retrieve internally available definitions (such as *module*)
from the compiler. Generated *module(s)* can be resolved by name
directly, other definitions such as *extension* and *grouping* will
need to use the (type, key) syntax.

### compile (schema [, map])

The compiler will process the input YANG schema text and perform
various `constrct` operations on the schema tree based on detected
`extensions` according to defined specifications.

It will return an object with the name of the module as key and the
generated `class` object as value.

### preprocess (schema [, map])

The compiler will process the input YANG schema text and perform
various `preprocess` operations on the schema tree based on detected
`extensions` according to defined specifications.

It will return an object in following format:

```js
{
  schema: "contains the new schema as JS object tree",
  map: "contains the discovered meta definitions extracted from the schema"
}
```

### parse (schema)

The compiler will process the input YANG schema text and return JS
object tree representation.

### dump (obj [, opts])

The compiler will dump the provided obj back into YANG schema string
format (if possible).

Currently it supports `opts.indent` parameter which can be used to
specify number of spaces to use for indenting YANG statement blocks.
If not supplied, the generated output will omit newlines and other
spacing for compact YANG output.

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
d = yang.dump (yang.load c), indent: 2

# the above operations will result in equivalent output below

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
