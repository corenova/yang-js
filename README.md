# yang-js

YANG parser and evaluator

Super light-weight and fast. Produces adaptive JS objects bound by
YANG schema expressions according to
[RFC 6020](http://tools.ietf.org/html/rfc6020)
specifications. Composes dynamic YANG schema expressions by analyzing
arbitrary JS objects.

  [![NPM Version][npm-image]][npm-url]
  [![NPM Downloads][downloads-image]][downloads-url]

```coffeescript
Yang = require 'yang-js'
schema = """
  container foo {
    leaf a { type string; }
    leaf b { type uint8; }
	list bar {
	  key "b1";
	  leaf b1 { type uint16; }
	  container blob;
    }
  }
  """
model = (Yang schema) {
  foo:
    a: 'apple'
    b: 10
	bar: [
	  { b1: 100 }
	]
}
```

## Installation

```bash
$ npm install yang-js
```

When using with the web browser, grab the *minified* build inside
`dist/yang.min.js` (currently **~100KB**).

For development/testing, clone from repo and initialize:

```bash
$ git clone https://github.com/corenova/yang-js
$ cd yang-js
$ npm install
```

## Features

* Robust parsing
* Focus on high performance
* Extensive test coverage
* Flexible control logic binding
* Powerful XPATH expressions
* Isomorphic runtime
* Adaptive validations
* Dynamic schema generation
* Granular event subscriptions

Please note that `yang-js` is not a code-stub generator based on YANG
schema input. It directly embeds YANG schema compliance into ordinary
JS objects as well as generates YANG schema(s) from ordinary JS
objects.

## Quick Start

Here's a quick example for using this module in coffeescript:

```coffeescript
Yang = require 'yang-js'
schema = """
  container foo {
    leaf a { type string; }
    leaf b { type uint8; }
  }
  """
model = Yang.parse(schema).eval {
  foo:
    a: 'apple'
    b: 10
}
```

The example above uses the *explict* long-hand version of using this
module, which uses the [parse](./src/yang.litcoffee#parse-schema)
method to generate the [Yang expression](./src/yang.litcoffee) and
immediately perform an [eval](./src/yang.litcoffee#eval-data-opts)
using the [Yang expression](./src/yang.litcoffee) for the passed-in JS
data object.

Since the above is a common usage pattern sequence, this module also
provides a *cast-style* short-hand version as follows:

```coffeescript
model = (Yang schema) {
  foo:
    a: 'apple'
    b: 10
}
```

It is functionally equivalent to the *explicit* version but provides
cleaner syntactic expression regarding how the data object is being
*cast* with the `Yang` expression to get back a new schema-driven
object.

Once you have the `model` instance, you can directly interact with its
properties and see the schema enforcement and validations in action.

As the above example illustrates, the `yang-js` module takes a
free-form approach when dealing with YANG schema statements. You can
use **any** YANG statement as the top of the expression and
[parse](./src/yang.litcoffee#parse-schema) it to return a
corresponding YANG expression instance. However, only YANG expressions
that represent a data node element will
[eval](./src/yang.litcoffee#eval-data-opts) to generate a new
[Property](./src/property.litcoffee) instance. Also, only `module`
schemas will [eval](./src/yang.litcoffee#eval-data-opts) to generate a
new [Model](./src/model.litcoffee) instance.

## Reference Guides

- [Getting Started Guide](./TUTORIAL.md)
- [Storing Data](http://github.com/corenova/yang-store)
- [Expressing Interfaces](http://github.com/corenova/yang-express)
- [Automating Documentation](http://github.com/corenova/yang-swagger)
- [Coverage Report](./test/yang-compliance-coverage.md)

## Bundled YANG Modules

- [iana-crypt-hash.yang](./schema/iana-crypt-hash.yang)
- [ietf-yang-types.yang](./schema/ietf-yang-types.yang)
- [ietf-inet-types.yang](./schema/ietf-inet-types.yang)
- [ietf-yang-library.yang](./schema/ietf-yang-library.yang) ([bindings](./src/module/ietf-yang-library.coffee))
- [yang-meta-types.yang](./schema/yang-meta-types.yang)

Please refer to
[Working with Multiple Schemas](./TUTORIAL.md#working-with-multiple-schemas)
section of the [Getting Started Guide](./TUTORIAL.md) for usage
examples.

## API

Below are the list of methods provided by the `yang-js` module. You
can click on each method entry for detailed info on usage.

### Main module

The following operations are available from `require('yang-js')`.

- [parse (schema)](./src/yang.litcoffee#parse-schema)
- [compose (data)](./src/yang.litcoffee#compose-data-opts)
- [resolve (name)](./src/yang.litcoffee#resolve-from-name)
- [import (name)](./src/yang.litcoffee#import-name-opts)

Please note that when you load the main module, it will attempt to
automatically register `.yang` extension into `require.extensions`.

### Yang instance

The [Yang](./src/yang.litcoffee) instance is created from
`parse/compose` operations from the main module.

- [compile ()](./src/yang.litcoffee#compile)
- [bind (obj)](./src/yang.litcoffee#bind-obj)
- [eval (data)](./src/yang.litcoffee#eval-data-opts)
- [extends (schema)](./src/yang.litcoffee#extends-schema)
- [locate (ypath)](./src/yang.litcoffee#locate-ypath)
- [toString ()](./src/yang.litcoffee#tostring-opts)
- [toJSON ()](./src/yang.litcoffee#tojson)

### Property instance

The [Property](./src/property.litcoffee) instances are created during
[Yang.eval](./src/yang.litcoffee#eval-data-opts) operation and are
bound to every *node element* defined by the underlying
[Yang](./src/yang.litcoffee) schema expression.

- [join (obj)](./src/property.litcoffee#join-obj)
- [get (pattern)](./src/property.litcoffee#get-pattern)
- [set (value)](./src/property.litcoffee#set-value)
- [merge (value)](./src/property.litcoffee#merge-value)
- [create (value)](./src/property.litcoffee#create-value)
- [remove ()](./src/property.litcoffee#remove-value)
- [find (pattern)](./src/property.litcoffee#find-pattern)
- [in (pattern)](./src/model.litcoffee#in-pattern)
- [do (args...)](./src/property.litcoffee#do-args)
- [toJSON ()](./src/property.litcoffee#tojson)

Please refer to [Property](./src/property.litcoffee) for a list of all
available properties on this instance.

### Model instance

The [Model](./src/model.litcoffee) instance is created from
[Yang.eval](./src/yang.litcoffee#eval-data-opts) operation for
YANG `module` schema and aggregates
[Property](./src/property.litcoffee) instances.

This instance also *inherits* all [Property](./src/property.litcoffee)
methods and properties.

- [access (model)](./src/model.litcoffee#access-model)
- [enable (feature)](./src/model.litcoffee#enable-feature)
- [save ()](./src/model.litcoffee#save)
- [rollback ()](./src/model.litcoffee#rollback)
- [on (event)](./src/model.litcoffee#on-event)
- [do (path, args...)](./src/model.litcoffee#do-path-args)

Please refer to [Model](./src/model.litcoffee) for a list of all
available properties on this instance.

## Examples

**Jukebox** is a simple example YANG module extracted from
[RFC 6020](http://tools.ietf.org/html/rfc6020). This example
implementation is included in this repository's [example](./example)
folder and exercised as part of the test suite. It demonstrates use of
the [register](./src/yang.litcoffee#register) and
[import](./src/yang.litcoffee#import-name-opts) facilities for
loading the YANG schema file and binding various control logic
behavior.

 - [YANG Schema](./example/jukebox.yang)
 - [Schema Bindings](./example/jukebox.coffee)

**Promise** is a resource reservation module implemented for
[OPNFV](http://opnfv.org). This example implementation is hosted in a
separate GitHub repository
[opnfv/promise](http://github.com/opnfv/promise) and utilizes
`yang-js` for the complete implementation. It demonstrates use of
multiple YANG data models in modeling complex systems. Please be sure
to [check it out](http://github.com/opnfv/promise) to learn more about
advanced usage of `yang-js`.

## Tests

To run the test suite, first install the dependencies, then run `npm
test`:
```
$ npm install
$ npm test
```

Also refer to [Compliance Report](./test/yang-compliance-coverage.md)
for the latest [RFC 6020](http://tools.ietf.org/html/rfc6020) YANG
specification compliance. There's also **active** effort to support
the latest **YANG 1.1** draft specifications. You can take a look at
the *mocha* test suite in the [test](./test) directory for compliance
coverage unit-tests and other examples.

## License
  [Apache 2.0](LICENSE)

This software is brought to you by
[Corenova Technologies](http://www.corenova.com). We'd love to hear
your feedback.  Please feel free to reach me at <peter@corenova.com>
anytime with questions, suggestions, etc.

[npm-image]: https://img.shields.io/npm/v/yang-js.svg
[npm-url]: https://npmjs.org/package/yang-js
[downloads-image]: https://img.shields.io/npm/dt/yang-js.svg
[downloads-url]: https://npmjs.org/package/yang-js
