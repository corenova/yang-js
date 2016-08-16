# Dynamic YANG Schema Composition

## Examples

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
schema = yang.compose {
  bar:
    a: 'hello'
    b: 123
}, tag: 'foo'
console.log schema.toString()
```

The output of `schema.toString()` looks as follows:

```
container foo {
  container bar {
    leaf a { type string; }
    leaf b { type number; }
  }
}
```

Please note that [compose](../src/yang.litcoffee#compose-data-opts)
detected the top-level YANG construct to be a simple `container`
instead of a `module`. It will only auto-detect as a `module` if any
of the properties of the top-level object contains a `function` or the
passed-in object itself is a `named function` with additional
properties.

Below example will auto-detect as `module` since a simple `container`
cannot contain a *function* as one of its properties.

```coffeescript
yang = require 'yang-js'
obj =
  bar:
    a: 'hello'
    b: 123
  test: ->
schema = yang.compose obj, { tag: 'foo' }
console.log schema.toString()
```

Applying `compose` on the `yang-js` library itself will produce the
following:

```js
yang.compose(require('yang-js'), { tag: 'yang' });
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
yang = require 'yang-js'
obj =
  bar:
    a: 'hello'
    b: 123
schema = yang.compose obj, { tag: 'foo', kind: 'module' }
console.log schema.toString()
```

When you *manually* alter the `Yang` expression instance, it will
internally trigger a check for scope validation and reject if the the
change will render the current schema invalid. Basically, you can't
simply change a `container` that contains other elements into a `leaf`
or any other arbitrary kind.
