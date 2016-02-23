# yang-js

YANG parser and compiler

This module provides YANG schema processing according to
[RFC 6020](http://tools.ietf.org/html/rfc6020) specifications.

For more advanced tooling (such as cli, express, etc.) built on top of this
module, be sure to check out
[YangForge](https://github.com/saintkepha/yangforge).

## Installation

```bash
$ npm install yang-js --save
```

## API

Here's an example for using this module:

```javascript
yang = require('yang-js');
fs   = require('fs');

try {
  var out = yang.load(fs.readFileSync('./example/jukebox.yang','utf8'));
  console.log(out.resolve('example-jukebox'));
} catch (e) {
  console.log(e)
}
```

### load (schema...)

*Recommended primary interface*

### parse (schema)

The compiler will process the input YANG schema text and return JS
object tree representation.

### preprocess (schema [, map])

The compiler will process the input YANG schema text and perform
various `preprocess` operations on the schema tree based on detected
`extensions` according to defined specifications (which can be
modified via `use`).

It will return an object in following format:

```
{
  schema: <contains the new schema as JS object tree>
  map: <contains the discovered meta definitions extracted from the schema>
}
```

### compile (schema [, map])

The compiler will process the input YANG schema text and perform
various `constrct` operations on the schema tree based on detected
`extensions` according to defined specifications.

It will return an object with the name of the module as key and the
generated `class` object as value.


### use (spec...)

You can pass in additional YANG language specifications for processing
extensions and typedefs as a YAML text or JS object. This call can be
invoked prior to any of the above operations to alter the behavior of
the `Compiler` itself.

## License
  [Apache 2.0](LICENSE)

