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

### load (spec/schema...)

*Recommended primary interface*

### parse (schema)

TBD

### preprocess (schema [, map])

TBD

### compile (schema [, map])

TBD

## License
  [Apache 2.0](LICENSE)

