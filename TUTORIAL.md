# Getting Started with yang-js

This guide/tutorial will provide various examples around usage of
`yang-js` library for working with YANG schemas and generated
Models. It will get better soon... :-)

## Table of Contents

- [Terminology](#terminology)
- [Working with Yang Schema](#working-with-yang-schema)
  - [Composite Type](#composite-type)
  - [Schema Extension](#schema-extension)
  - [Schema Conversion](#schema-conversion)
  - [Schema Composition](#schema-composition)
  - [Schema Binding](#schema-binding)
- [Working with Multiple Schemas](#working-with-multiple-schemas)
  - [Preload Dependency](#preload-dependency)
  - [Automatic Resolution](#automatic-resolution)
  - [External Package Bundle](#external-package-bundle)
  - [Internal Package Bunlde](#internal-package-bundle)
- [Working with Models](#working-with-models)
  - [Model Events](#model-events)

## Terminology

Here's a collection of commonly used terms and their definitions
within this module and other related modules:

- **Schema**: A descriptive resource that expresses the data
  hierarchy, constraints, and behavior of a data model
- **Model**: An instance of Schema evaluated with data
- **Component**: An implementation resource that associates control
  logic bindings to a Model

## Working with Yang Schema

### Composite Type

A handy convention is to define/save the generated
[Yang.eval](./src/yang.litcoffee#main-constructor) function as a
**Composite Type** definition and re-use for creating multiple
adaptive schema objects:

```coffeescript
FooType = (Yang schema)
foo1 = (FooType) {
  foo:
    a: 'apple'
    b: 10
}
foo2 = (FooType) {
  foo:
    a: 'banana'
    b: 20
}
```

### Schema Extension

```javascript
var schema = Yang.parse('container foo { leaf a; }');
var model = schema.eval({ foo: { a: 'bar' } });
// try assigning a new arbitrary property
model.foo.b = 'hello';
console.log(model.foo.b);
// returns: undefined (since not part of schema)
```

Here comes the magic:

```javascript
// extend the previous container foo expression with an additional leaf
schema.extends('leaf b;')
model.foo.b = 'hello';
console.log(model.foo.b)
// returns: 'hello' (since now part of schema!)
```

The [extends](./src/yang.litcoffee#extends-schema) mechanism provides
interesting programmatic approach to *dynamically* modify a given
`Yang` expression over time on a running system.

### Schema Conversion

```
module foo {
  description "A Foo Example";
  container bar {
    leaf a {
      type string;
    }
    leaf b {
      type uint8;
    }
  }
}
```

Result of [parse](./src/yang.litcoffee#parse-schema) looks like:

```js
{ kind: 'module',
  tag: 'foo',
  description:
   { kind: 'description',
     tag: 'A Foo Example' },
  container:
   [ { kind: 'container',
       tag: 'bar',
       leaf: [Object] } ] }
```

When the above `Yang` expression is converted
[toJSON](./src/yang.litcoffee#tojson):

```js
{ module: 
   { foo: 
      { description: 'A Foo Example',
        container: 
          { bar: { leaf: { a: [Object], b: [Object] } } } } } }
```

### Schema Composition

Below example in coffeescript demonstrates typical use:

```coffeescript
Yang = require 'yang-js'
schema = Yang.compose {
  bar:
    a: 'hello'
    b: 123
}, tag: 'foo'
console.log schema.toString()
```

The output of [schema.toString()](./src/yang.litcoffee#tostring) looks
as follows:

```
container foo {
  container bar {
    leaf a { type string; }
    leaf b { type number; }
  }
}
```

Please note that [compose](../src/yang.litcoffee#compose-data)
detected the top-level YANG construct to be a simple `container`
instead of a `module`. It will only auto-detect as a `module` if any
of the properties of the top-level object contains a `function` or the
passed-in object itself is a `named function` with additional
properties.

Below example will auto-detect as `module` since a simple `container`
cannot contain a *function* as one of its properties.

```coffeescript
Yang = require 'yang-js'
obj =
  bar:
    a: 'hello'
    b: 123
  test: ->
schema = Yang.compose obj, { tag: 'foo' }
console.log schema.toString()
```

This is a very handy facility to dynamically discover YANG schema
mapping for any arbitrary asset being used (even NPM modules) so that
you can qualify/validate the target resource for schema compliance.

You can also **override** the detected YANG construct as follows:

```coffeescript
Yang = require 'yang-js'
obj =
  bar:
    a: 'hello'
    b: 123
schema = Yang.compose obj, { tag: 'foo', kind: 'module' }
console.log schema.toString()
```

When you *manually* alter the `Yang` expression instance, it will
internally trigger a check for scope validation and reject if the the
change will render the current schema invalid. Basically, you can't
simply change a `container` that contains other elements into a `leaf`
or any other arbitrary kind.

### Schema Binding

```coffeescript
Yang = require 'yang-js'
schema = """
  module foo {
    feature hello;
    container bar {
      leaf readonly {
        config false;
        type boolean;
      }
    }
    rpc test;
  }
"""
schema = Yang.parse(schema).bind {
  'feature(hello)': -> # provide some capability
  '/foo:bar/readonly': -> true
  '/test': -> @output = "success"
}
```

In the above example, a `key/value` object was passed-in to the
[bind](./src/yang.litcoffee#bind-obj) method where the `key` is a
string that will be mapped to a Yang Expression contained within the
expression being bound. It accepts XPATH-like expression which will be
used to locate the target expression within the schema. The `value` of
the binding must be a JS function, otherwise it will be *silently*
ignored.

You can also [bind](./src/yang.litcoffee#bind-obj) a function directly
to a given Yang Expression instance as follows:

```coffeescript
Yang = require 'yang-js'
schema = Yang.parse('rpc test;').bind -> @output = "ok"
```

Please note that calling [bind](./src/yang.litcoffee#bind-obj)
more than once on a given [Yang](./src/yang.litcoffee) expression
will *replace* any prior binding.

## Working with Multiple Schemas

### Preload Dependency

You can utilize
[Yang.import](./src/yang.litcoffee#import-name-opts) to load
the dependency module into the [Yang](./src/yang.litcoffee)
compiler:

```coffeescript
Yang = require('yang-js')
Yang.import('/some/path/to/dependency.yang')
```

You can also use built-in `require()` directly:

```coffeescript
require('yang-js')
require('/some/path/to/dependency.yang')
```

The pre-load approach is *iterative* in that you would need to ensure
dependency YANG modules are loaded in the proper order of the nested
dependency chain.


### Automatic Resolution

When utilizing `Yang.import` or `register/require`, the
[Yang](./src/yang.litcoffee) compiler internally utilizes
[Yang.resolve](./src/yang.litcoffee#resolve-from-name) to attempt
to locate dependency modules automatically.

It first checks local `package.json` to resolve the dependency via
[External](#external-package-bundle) or
[Internal](#internal-package-bundle) definitions. If not found, it
will try to locate the `some-dependency.yang` in the same directory
that the *dependent* schema is being required.

### External Package Bundle

To utilize YANG modules bundled in an external package inside your own
app, you can add a section inside your local `package.json` as
follows:

```json
{
  "models": {
	"ietf-yang-types": "yang-js",
	"ietf-inet-types": "yang-js",
    "yang-store": "yang-js"
  }
}
```

This will enable `Yang.resolve` and `Yang.import` to locate these
YANG modules from the `yang-js` package.

### Interal Package Bundle

To allow external packages to perform
[Automatic Resolution](#automatic-resolution) of modules being
provided by your app, as well as for your own app to resolve local
dependencies, you can add a section inside your `package.json` as
follows:

```json
{
  "models": {
	"my-module": "./some/path/to/my-module.yang",
	"my-bound-module": "./lib/my-bound-module.js"
  }
}
```

Please note that you can reference a YANG schema file directly as well
as a **JavaScript file** which exports a
[Yang](./src/yang.litcoffee) schema instance. The second approach
is useful for exporting **bound** schemas (see
[Schema Binding](#schema-binding)) which contains function bindings on
the YANG schema.

## Working with Models

### Model Events

```coffeescript
Yang = require 'yang-js'
schema = """
  module foo {
    list bar {
      container obj {
        leaf a { type string; }
        leaf b { type uint8; }
      }
    }
  }
  """
model = (Yang schema) {
  'foo:bar': [
    { obj: { a: 'apple', b: 10 } }
    { obj: { a: 'orange, b: 20 } }
  ]
}
model.on 'update', (prop, prev) ->
  # do something with 'prop'
```

The example above will register an event listener using
[Model.on](./src/model.litcoffee#on-event) to trigger whenever the
data state of the `model` is updated.

You can also utilize XPATH expressions to only listen for specific
events occurring inside the data tree:

```coffeescript
model.on 'update', '/foo:bar/obj/a', (prop, prev) ->
  console.log "the property 'a' changed on one of the elements in the 'list bar'"
model.in('/foo:bar[0]/obj/a').set 'pineapple' # trigger event
model.in('/foo:bar[1]/obj/a').set 'grape'     # trigger event
```

