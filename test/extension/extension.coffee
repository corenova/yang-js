should = require 'should'

describe 'simple extension', ->
  schema = """
    extension foo-ext {
      description "A simple extension";
      argument "name";
    }
  """

  it "should parse simple extension statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo-ext')
    y.should.have.property('kind').and.equal('extension')

describe 'extended extension', ->
  schema = """
  module foo {
    extension c-define {
      description
        "Takes as argument a name string.
        Makes the code generator use the given name in the
        #define.";
      argument "name";
    }
    container interfaces {
      c-define "MY_INTERFACES";
    }
  }
  """

  it "should parse use of extension statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should handle binding extension", ->
    y = Yang.parse(schema).bind 'extension(c-define)': construct: (a) -> a
    y.locate('foo:interfaces').nodes.should.have.length(1);

describe 'unknown extension', ->
  schema = """
  module foo {
    something;
    unknown-define "HELLO";
  }
  """
  it "should fail parsing unknown extension statement", ->
    (-> Yang.parse schema).should.throw()

describe 'imported extension', ->
  imported_schema = """
  module foo2 {
    extension c-define {
      description
        "Takes as argument a name string.
        Makes the code generator use the given name in the
        #define.";
      argument "name";
    }
  }
  """
  schema= """
  module bar {
    import foo2 {
      prefix foo;
    }
    container interfaces {
      foo:c-define "MY_INTERFACES";
    }
  }
  """
  it "should parse imported extension", ->
    y1 = Yang.use (Yang.parse imported_schema)
    y2 = Yang.parse schema
    y2.should.have.property('tag').and.equal('bar')

