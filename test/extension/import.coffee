should = require 'should'

describe "simple import", ->
  schema = """
    module foo {
      prefix foo;
      namespace "http://corenova.com/yang/foo";

      import bar {
        prefix bar;
      }

      description "extended module test";
      contact "Peter K. Lee <peter@corenova.com>";
      organization "Corenova Technologies, Inc.";
      reference "http://github.com/corenova/yang-js";

      container xyz {
        description "empty container";
        uses bar:some-shared-info;
      }
    }
    """
  imported_schema = """
    module bar {
      prefix bar;
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

  it "should parse import statement", ->
    y1 = yang.use (yang.parse imported_schema)
    y2 = yang.parse schema
    y2.prefix.should.have.property('tag').and.equal('foo')

describe 'submodule', ->
  schema1 = """
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
  schema2 = """
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
  it.skip "should parse submodule statement", ->
    y = yang.parse schema2
    console.dir y
    y.prefix.should.have.property('tag').and.equal('bar')
