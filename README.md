# yang-js

YANG parser and compiler

This module provides YANG schema processing according to
[RFC 6020](http://tools.ietf.org/html/rfc6020) specifications.

For more advanced composition tooling with built-in interface
generators such as cli, express, restjson, websocket, etc. please
check out [YangForge](https://github.com/saintkepha/yangforge).

Also refer to [Coverage Report](./yang-v1-coverage.md) for the latest
[RFC 6020](http://tools.ietf.org/html/rfc6020) YANG specification
compliance.

## Installation

```bash
$ npm install yang-js
```

## API

Here's an example for using this module:

```js
var yang = require('yang-js');
var fs   = require('fs');

try {
  var out = yang.load(fs.readFileSync('./example/jukebox.yang','utf8'));
  var jukebox = out.resolve('example-jukebox');
  console.log(yang.dump(jukebox));
} catch (e) {
  console.log(e);
}
```

### load (schema...)

*Recommended primary interface*

You can pass in various schema(s) for compiling and defining into the
`Compiler` instance.

It accepts schema(s) in various formats: YANG, YAML, and JS object

You can also pass in additional YANG language specifications for
processing *extensions* and *typedefs*. Specifications that alter the
behavior of the generated output are processed using a new built-in
*extension* called `specification`.  For an example of how YANG v1.0
language processing is defined, take a look at [YANG v1
Specification](./yang-v1-spec.yaml).  It utilizes [Data
Synth](http://github.com/saintkepha/data-synth) library for generating
the JS class object hierarchy.

This call returns a new Compiler instance with updated internal
definitions. It can then be used to load/compile additional schema(s)
or `resolve` to retrieve the generated outputs.

### resolve (type [, key)

Used after a `load` operation to retrieve the internal definitions
(such as *module*). Generated *module(s)* are resolved by name
directly, other definitions such as *extension* and *grouping* will
need to use the (type, key) syntax.

### parse (schema)

The compiler will process the input YANG schema text and return JS
object tree representation.

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

### compile (schema [, map])

The compiler will process the input YANG schema text and perform
various `constrct` operations on the schema tree based on detected
`extensions` according to defined specifications.

It will return an object with the name of the module as key and the
generated `class` object as value.

### dump (obj)

The compiler will dump the provided obj back into YANG schema format
(if possible).

## License
  [Apache 2.0](LICENSE)

