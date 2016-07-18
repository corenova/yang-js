# yang-js

YANG parser and composer

Super light-weight and fast. Produces adaptive JS objects bound by
YANG schema expressions according to
[RFC 6020](http://tools.ietf.org/html/rfc6020)
specifications. Composes dynamic YANG schema expressions by analyzing
arbitrary JS objects.

  [![NPM Version][npm-image]][npm-url]
  [![NPM Downloads][downloads-image]][downloads-url]

```coffeescript
yang = require 'yang-js'
schema = """
  container foo {
    leaf a { type string; }
    leaf b { type uint8; }
  }
  """
obj = (yang schema) {
  foo:
    a: 'apple'
    b: 10
}
```

## Installation

```bash
$ npm install yang-js
```

When using with the web browser, be sure to grab the
[minified build](./dist/yang.min.js) (currently **~85KB**).

## Features

* Robust parsing
* Focus on high performance
* Extensive test coverage
* Flexible control logic binding
* Powerful XPATH expressions
* Isomorphic runtime
* Adaptive validations
* Dynamic schema generation

Please note that `yang-js` is not a code-stub generator based on YANG
schema input. It directly embeds YANG schema compliance into ordinary
JS objects as well as generates YANG schema(s) from oridnary JS
objects.

## API

Here's a quick example for using this module in coffeescript:

```coffeescript
yang = require 'yang-js'
schema = """
  container foo {
    leaf a { type string; }
    leaf b { type uint8; }
  }
  """
obj = yang.parse(schema).eval {
  foo:
    a: 'apple'
    b: 10
}
```

The example above uses the *explict* long-hand version of using this
module, which uses the `parse` method to generate the `Yang`
expression and immediately perform an `eval` using the `Yang`
expression for the passed-in JS data object.

Since the above is a common usage pattern sequence, this module also
provides a *cast-style* short-hand version as follows:

```coffeescript
obj = (yang schema) {
  foo:
    a: 'apple'
    b: 10
}
```

It is functionally equivalent to the *explicit* version but provides
cleaner syntactic expression regarding how the data object is being
*cast* with the `Yang` expression to get back a new schema-driven
object.

Another handy convention is to define/save the generated `Yang.eval`
function as a type definition and re-use for multiple objects:

```coffeescript
FooObject = (yang schema)
foo1 = (FooObject) {
  foo:
    a: 'apple'
    b: 10
}
foo2 = (FooObject) {
  foo:
    a: 'banana'
    b: 20
}
```

As the above example illustrates, the `yang-js` module takes a
free-form approach when dealing with YANG schema statements. You can
use **any** YANG statement as the top of the expression and `parse` it
to return a corresponding YANG expression instance. However, only YANG
expressions that represent a data element will `eval` to generate a
new object (for obvious reasons).

### parse (schema)

This call *accepts* a YANG schema string and returns a new `Yang`
expression containing the parsed schema object and its
sub-expression(s). It will perform syntactic and semantic parsing of
the input YANG schema. If any validation errors are encountered, it
will throw the appropriate error along with the context information
regarding the error.

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
model = yang.parse """
  module foo {
    description hello;
    container bar {
      leaf a { type string; }
      leaf b { type int8; }
    }
  }
  """
```

For additional info regarding the `Yang` expression instance, check
[Class Yang](#class-yang-expression) documentation below.

### compose (name, data)

This call *accepts* an arbitrary JS object and it will attempt to
convert it into a structural `Yang` expression instance. It will
analyze the passed in JS data and perform best match mapping to an
appropriate YANG schema representation to describe the input
data. This method will not be able to determine conditionals or any
meta-data to further constrain the data, but it should provide a good
starting point with the resulting `Yang` expression instance.

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
model = yang.compose 'foo', {
  bar:
    a: 'hello'
    b: 123
}
console.log model.toString()
```

The output of `model.toString()` looks as follows:

```
container foo {
  container bar {
    leaf a { type string; }
    leaf b { type number; }
  }
}
```

Please note that `compose` detected the top-level YANG construct to
be a simple `container` instead of a `module`. It will only
auto-detect as a `module` if any of the properties of the top-level
object contains a `function` or the passed-in object itself is a
`named function` with additional properties.

Below example will auto-detect as `module` since a simple `container`
cannot contain a *function* as one of its properties.

```coffeescript
yang = require 'yang-js'
model = yang.compose 'foo', {
  bar:
    a: 'hello'
    b: 123
  test: ->
}
console.log model.toString()
```

Applying `compose` on the `yang-js` library itself will produce the
following:

```js
yang.compose('yang', require('yang-js'));
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
model = yang.compose 'foo', {
  bar:
    a: 'hello'
    b: 123
}, kind: 'module'
console.log model.toString()
```

When you *manually* alter the `Yang` expression instance, it will
internally trigger a check for scope validation and reject if the the
change will render the current schema invalid. Basically, you can't
simply change a `container` that contains other elements into a `leaf`
or any other arbitrary kind.

For additional info regarding the `Yang` expression instance, check
[Class Yang](#class-yang-expression) documentation below.

### require (filename)

This call provides a convenience mechanism for dealing with YANG
schema module dependencies. It performs parsing of the YANG schema
content from the specified `filename` and saves the generated `Yang`
expression inside the internal `Registry`.

Once a given YANG module has been saved inside the `Registry`,
subsequent `parse` of YANG schema that *import* the saved module will
successfully resolve.

Typical usage scenario for this pattern is to internally define common
modules such as `ietf-yang-types` which can then be *imported* by
other schemas.

It will also return the new `Yang` expression instance (to do with as
you please).

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = require 'yang-js'
dependency1 = yang.require './some-dependency.yang'
dependency2 = yang.require './some-other-dependency.yang'
model = yang.parse """
  module foo {
    import some-dependency { prefix sd; }
    import some-other-dependency { prefix sod; }
  }
  """
```

Please note that this method will look for the `filename` in current
working directory of the script execution if the `filename` is a
relative path.

This method also attempts to dynamically resolve `import` dependencies
by looking for dependent YANG schema files in the same directory from
which the `require` is being processed. It will append `.yang`
extension to the `import` target-node identifier and attempt to
recursively retrieve any dependencies currently not found inside the
internal `Registry`.

While this is a convenient abstraction, it is recommended to use the
below `register` function and use Node.js built-in `require` mechanism
if possible as it will provide better handling when used with
`browserify`.

### register (opts={})

This call attempts to enable Node.js built-in `require` to handle
`.yang` extensions natively. If this is available in your Node.js
runtime, it is recommended to use this pattern rather than the above
`yang.require` method. Internally, it uses the above `yang.require`
method so it has the same handling behavior but also takes advantage
of Node.js built-in `require` search-path for retreiving the target
YANG schema.

This method simply attempts to associate `.yang` extension inside
`require` facility and will return the `yang-js` module as-is.

Below example in coffeescript demonstrates typical use:

```coffeescript
yang = (require 'yang-js').register()
dependency1 = require './some-dependency.yang'
dependency2 = require './some-other-dependency.yang'
dependency3 = require 'some-yang-app/some-app-module.yang'
```

Using this pattern ensures proper `browserify` generation as well as
ability to load YANG schema files from other Node.js modules.

## Class: Yang (Expression)

### bind (data)

Every instance of `Yang` expression can be *bound* with control logic
which will be used during `eval` to produce schema infused **adaptive
data object**.

This facility can be used to associate default behaviors for any
element in the configuration tree, as well as handler logic for
various YANG statements such as *rpc*, *feature*, etc.

This call will return the original Yang Expression instance with the
new bindings registered within the Yang Expression hierarchy.

Here's an example:

```coffeescript
yang = require 'yang-js'
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
model = yang.parse(schema).bind {
  'feature:hello': -> # provide some capability
  '/bar/readonly': -> true
  'rpc:test': (input, resolve, reject) -> resolve "success"
}
```

In the above example, a `key/value` object was passed-in to the `bind`
method where the `key` is a string that will be mapped to a Yang
Expression contained within the expression being bound. It accepts
XPATH-like expression which will be used to locate the target
expression within the schema. The `value` of the binding must be a JS
function, otherwise it will be *silently* ignored.

You can also `bind` a function directly to a given Yang Expression
instance as follows:

```coffeescript
yang = require 'yang-js'
model = yang.parse('rpc test;').bind (input, resolve, reject) -> resolve "ok"
```

Calling `bind` more than once on a given Yang Expression will
*replace* any prior binding.


### eval (data [, opts={}])

Every instance of `Yang` expression can be `eval` with arbitrary JS
data input which will apply the schema against the provided data and
return a schema infused **adaptive data object**.

This is an extremely useful construct which brings out the true power
of YANG for defining and governing arbitrary JS data structures.

Here's an example:

```javascript
var model = yang.parse('container foo { leaf a { type uint8; } }');
var obj = model.eval({ foo: { a: 7 } });
// obj is { foo: [Getter/Setter] }
// obj.foo is { a: [Getter/Setter] }
// obj.foo.a is 7
```

Basically, the input `data` will be YANG schema validated and
converted to a schema infused adaptive data object that dynamically
defines properties according to the schema expressions.

It currently supports the `opts.adaptive` parameter (default `true`)
which establishes a persistent binding relationship with the
underlying `Yang` expression instance.

What this means is that the `eval` generated output object will
dynamically **adapt** to any changes to the underlying `Yang`
expression instance. Refer to below `extends` section for additional
info.

### extends (schema...)

Every instance of `Yang` expression can be `extends` with additional
YANG schema string(s) and it will automatically perform `parse` of the
provided schema text and update itself accordingly.

This action also triggers an event emitter which will *retroactively*
adapt any previously `eval` produced adaptive data object instances to
react accordingly to the newly changed underlying schema
expression(s).

Here's an example:

```javascript
var model = yang.parse('container foo { leaf a; }');
var obj = model.eval({ foo: { a: 'bar' } });
// try assigning a new arbitrary property
obj.foo.b = 'hello';
console.log(obj.foo.b);
// returns: undefined (since not part of schema)
```

Here comes the magic:

```javascript
// extend the previous container foo expression with an additional leaf
model.extends('leaf b;')
obj.foo.b = 'hello';
console.log(obj.foo.b)
// returns: 'hello' (since now part of schema!)
```

The `extends` mechanism provides interesting programmatic approach to
*dynamically* modify a given `Yang` expression over time on a running
system. This inherent facility is one of the key reasons for the
recent forklift with the new `yang-js 0.14.x` branch.

### toString (opts={ space: 2 })

The current `Yang` expression will covert back to the equivalent YANG
schema text format.

At first glance, this may not seem like a useful facility since YANG
schema text is *generally known* before `parse` but it becomes highly
relevant when you consider a given `Yang` expression programatically
changing via `extends`.

Currently it supports `space` parameter which can be used to specify
number of spaces to use for indenting YANG statement blocks.  It
defaults to **2** but when set to **0**, the generated output will
omit newlines and other spacing for a more compact YANG output.

### toObject ()

The current `Yang` expression will convert into a simple JS object
format.

Using schema as below:

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

Result of `yang.parse` looks like:

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

When the above `Yang` expression is converted `toObject()`:
```js
{ module: 
   { foo: 
      { description: 'A Foo Example',
        container: 
          { bar: { leaf: { a: [Object], b: [Object] } } } } } }
```

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
[Corenova](http://www.corenova.com). We'd love to hear your feedback.
Please feel free to reach me at <peter@corenova.com> anytime with
questions, suggestions, etc.

[npm-image]: https://img.shields.io/npm/v/yang-js.svg
[npm-url]: https://npmjs.org/package/yang-js
[downloads-image]: https://img.shields.io/npm/dt/yang-js.svg
[downloads-url]: https://npmjs.org/package/yang-js
