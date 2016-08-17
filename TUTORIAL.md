# Getting Started with yang-js

This guide/tutorial will provide various examples around usage of
`yang-js` library for working with YANG schemas and generated
Models. It will get better soon... :-)

## Working with Yang Schema

### Multiple Models

A handy convention is to define/save the generated
[Yang.eval](./src/yang.litcoffee#main-constructor) function as a type
definition and re-use for creating multiple
[Models](./src/model.litcoffee):

```coffeescript
FooModel = (Yang schema)
foo1 = (FooModel) {
  foo:
    a: 'apple'
    b: 10
}
foo2 = (FooModel) {
  foo:
    a: 'banana'
    b: 20
}
```

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
  '[feature:hello]': -> # provide some capability
  '/foo:bar/readonly': -> true
  '/test': (input, resolve, reject) -> resolve "success"
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
schema = Yang.parse('rpc test;').bind (input, resolve, reject) -> resolve "ok"
```

Calling [bind](./src/yang.litcoffee#bind-obj) more than once on a
given Yang Expression will *replace* any prior binding.

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
[toObject](./src/yang.litcoffee#toobject):

```js
{ module: 
   { foo: 
      { description: 'A Foo Example',
        container: 
          { bar: { leaf: { a: [Object], b: [Object] } } } } } }
```

### Dynamic Composition

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

Applying `compose` on the `yang-js` library itself will produce the
following:

```js
Yang.compose(require('yang-js'), { tag: 'yang' });
{ kind: 'module',
  tag: 'yang',
  rpc:
  [ { kind: 'rpc', tag: 'parse' },
    { kind: 'rpc', tag: 'compose' },
    { kind: 'rpc', tag: 'require' },
    { kind: 'rpc', tag: 'register' } ],
  feature:
  [ { kind: 'feature', tag: 'Yang' },
    { kind: 'feature', tag: 'Expression' },
    { kind: 'feature', tag: 'Registry' } ] }
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

## Working with Models

### Model Events

```coffeescript
Yang = require 'yang-js'
schema = """
  list foo {
    container bar {
      leaf a { type string; }
      leaf b { type uint8; }
    }
  }
  """
model = (Yang schema) {
  foo: [
    { bar: { a: 'apple', b: 10 } }
    { bar: { a: 'orange, b: 20 } }
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
model.on 'update', '/foo/bar/a', (prop, prev) ->
  console.log "the property 'a' changed on one of the elements in the
  'list foo'"
model.foo[0].bar.a = 'pineapple' # trigger event
model.foo[1].bar.a = 'grape'     # trigger event
```

