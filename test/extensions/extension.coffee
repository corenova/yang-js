should = require 'should'

describe 'simple extension', ->
  schema = """
    extension foo-ext {
      description "A simple extension";
      argument "name";
    }
  """

  it "should parse simple extension statement", ->
    y = yang.parse schema
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
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')