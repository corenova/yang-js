should = require 'should'

describe 'simple schema', ->
  schema = 'module foo;'

  it "should parse simple module statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple module element", ->
    o = (Yang schema)()
    o.should.be.instanceof(Object)

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
    y = Yang.parse schema
    y.prefix.should.have.property('tag').and.equal('foo')

  it "should convert toJSON", ->
    y = Yang.parse schema
    obj = y.toJSON()
    obj.should.have.property('module').and.have.property('foo')

  it "should create extended module element", ->
    o = (Yang schema)()
    o.get('/').should.have.property('foo:bar')

  it "should evaluate configuration data", ->
    o = (Yang schema)
      'foo:bar':
        a: 'hello'
        b: 10
    o.get('foo:bar').should.have.property('a').and.equal('hello')
    o.get('foo:bar').should.have.property('b').and.equal(10)

  it "should implement functional module", ->
    o = (Yang schema)
      'foo:bar':
        a: 'hello'
        b: 10
      'foo:some-method-1': (input) ->
        bar = @get('/foo:bar')
        bar.a = input.a
        bar.b = input.b
        return message: 'success'
    o.get('some-method-1').do
      a: 'bye'
      b: 0
    .then (res) ->
      res.should.have.property('message').and.equal('success')
      o.get('foo:bar').should.have.property('a').and.equal('bye')
      o.get('foo:bar').should.have.property('b').and.equal(0)
    
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
      augment "/foo:bar" {
        leaf a3;
      }
    }
    """
  it "should parse augment module statement", ->
    y = Yang.parse schema
    y.prefix.should.have.property('tag').and.equal('foo')
    y.locate('/bar/a2').should.have.property('tag').and.equal('a2')
    y.locate('/bar/a3').should.have.property('tag').and.equal('a3')

  
describe 'augment schema (external)', ->
  before -> Yang.clear()
  
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
  it "should parse augment module statement", ->
    y1 = Yang.use (Yang.parse schema1)
    y2 = Yang.parse schema2
    y2.locate('/foo:c1/c2/bar:a2').should.have.property('tag').and.equal('a2')
  
describe "import schema", ->
  before -> Yang.clear()
  
  schema1 = """
    module foo {
      prefix foo;
      namespace "http://corenova.com/yang/bar";

      description "extended module test";
      contact "Peter K. Lee <peter@corenova.com>";
      organization "Corenova Technologies, Inc.";
      reference "http://github.com/corenova/yang-js";

      grouping some-shared-info {
        leaf a { type string; }
        leaf b { type uint8; }
      }
    }
  """
  schema2 = """
    module bar {
      prefix bar;
      namespace "http://corenova.com/yang/foo";

      import foo { prefix f; }

      description "extended module test";
      contact "Peter K. Lee <peter@corenova.com>";
      organization "Corenova Technologies, Inc.";
      reference "http://github.com/corenova/yang-js";

      container xyz {
        description "empty container";
        uses f:some-shared-info;
      }
    }
    """

  it "should parse import statement", ->
    y1 = Yang.use (Yang.parse schema1)
    y2 = Yang.parse schema2
    y2.prefix.should.have.property('tag').and.equal('bar')

describe 'include schema', ->
  before -> Yang.clear()
  
  schema = """
    module foo2 {
      prefix foo;
      namespace "http://corenova.com/yang/foo";

      include bar2 {
        revision-date 2016-06-28;
      }
      
      description "extended module test";
      contact "Peter K. Lee <peter@corenova.com>";
      organization "Corenova Technologies, Inc.";
      reference "http://github.com/corenova/yang-js";

      grouping some-shared-info {
        leaf a { type string; }
        leaf b { type uint8; }
      }
    }
    """
  it "should parse submodule schema", ->
    sub = """
      submodule bar2 {
        belongs-to foo2 {
          prefix foo2;
        }

        description "extended module test";
        contact "Peter K. Lee <peter@corenova.com>";
        organization "Corenova Technologies, Inc.";
        reference "http://github.com/corenova/yang-js";

        revision 2016-06-28 {
          description
            "Test revision";
        }
        container xyz {
          uses foo2:some-shared-info;
        }
      }
      """
    y = Yang.use (Yang.parse sub, false) # compile=false necessary!
    y['belongs-to'].should.have.property('tag').and.equal('foo2')

  it "should parse include statement", ->
    y = Yang.parse schema
    xyz = y.match('container','xyz')
    xyz.should.have.property('leaf')
