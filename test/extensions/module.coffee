should = require 'should'

describe 'simple schema', ->
  schema = 'module foo;'

  it "should parse simple module statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple module element", ->
    o = (yang schema)()
    o.should.have.property('__')

describe 'extended schema', ->
  schema = """
    module foo {
      prefix foo;
      namespace "http://corenova.com";
      
      description "extended module test";
      contact "Peter K. Lee <peter@corenova.com>";
      organization "Corenova Technologies, Inc.";
      reference "http://github.com/corenova/yang-js";

      identity core {
        description "the core identity";
      }

      grouping some-shared-info {
        leaf a { type string; }
        leaf b { type uint8; }
      }

      container bar {
        uses some-shared-info;
      }

      rpc some-method-1 {
        description "update config for 'bar'";
        input {
          uses some-shared-info;
        }
      }
      rpc some-method-2;
    }
    """
  it "should parse extended module statement", ->
    y = yang.parse schema
    y.prefix.should.have.property('tag').and.equal('foo')

  it "should create extended module element", ->
    o = (yang schema)()
    o.should.have.property('bar')

  it "should evaluate configuration data", ->
    o = (yang schema)
      bar:
        a: 'hello'
        b: 10
    o.bar.should.have.property('a').and.equal('hello')
    o.bar.should.have.property('b').and.equal(10)

  it "should implement functional module", ->
    o = (yang schema)
      bar:
        a: 'hello'
        b: 10
      'some-method-1': (input, resolve, reject) ->
        bar = @get '../bar'
        bar.a = input.a
        bar.b = input.b
        resolve message: 'success'
    o.bar.should.have.property('a').and.equal('hello')
    o.bar.should.have.property('b').and.equal(10)
    o['some-method-1']
      a: 'bye'
      b: 0
    .then (res) ->
      res.should.have.property('message').and.equal('success')
      o.bar.should.have.property('a').and.equal('bye')
      o.bar.should.have.property('b').and.equal(0)
    
describe 'augment schema (local)', ->
  schema = """
    module foo {
      prefix foo;
      namespace "http://corenova.com";
      
      description "augment module test";

      container bar {
        leaf a1;
      }

      augment "/foo:bar" {
        leaf a2;
      }
    }
    """
  it "should parse augment module statement", ->
    y = yang.parse schema
    y.prefix.should.have.property('tag').and.equal('foo')
    y.locate('/bar/a2').should.have.property('tag').and.equal('a2')
  
describe 'augment schema (external)', ->
  schema1 = """
    module foo {
      prefix foo;
      namespace "http://corenova.com";
      
      description "augment module test";

      container c1 {
        container c2 {
          leaf a1;
        }
      }
    }
    """
  schema2 = """
    module bar {
      prefix bar;

      import foo { prefix foo; }

      augment "/foo:c1/foo:c2" {
        leaf a2;
      }
    }
    """
  it.skip "should parse augment module statement", ->
    y1 = yang.parse schema1
    yang.Registry.extend y1, merge: true

    y2 = yang.parse schema2
    y1.locate('/c1/c2/a2').should.have.property('tag').and.equal('a2')
  
