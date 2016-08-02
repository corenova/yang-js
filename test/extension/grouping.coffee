should = require 'should'

describe 'simple schema', ->
  schema = 'grouping foo;'

  it "should parse simple grouping statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should not create simple grouping element", ->
    o = (yang schema)()
    should.not.exist(o)

describe 'extended schema', ->
  schema = """
    grouping foo {
      description "extended grouping test";
      leaf-list vegetables;
      leaf favorite;
    }
    """
  it "should parse extended grouping statement", ->
    y = yang.parse schema
    y.leaf.should.be.instanceOf(Array).and.have.length(1)

  it "should not create extended grouping element", ->
    o = (yang schema)()
    should.not.exist(o)

describe 'nested schema', ->
  schema = """
    grouping foo {
      description "extended grouping test";
      grouping attr {
        leaf color;
      }
      container fruit {
        uses attr;
        leaf favorite { type boolean; }
      }
    }
    """
  it "should parse nested grouping statement", ->
    y = yang.parse schema
    y.grouping.should.be.instanceOf(Array).and.have.length(1)

  it "should not create nested grouping element", ->
    o = (yang schema)()
    should.not.exist(o)

describe 'uses schema', ->
  schema = """
    container top {
      description "grouping usage test";
      grouping foo {
        leaf bar;
      }
      container user {
        uses foo;
        leaf name { type string; }
        leaf active { type boolean; }
      }
    }
    """
  it "should parse grouping uses container statement", ->
    y = yang.parse schema
    y.grouping.should.be.instanceOf(Array).and.have.length(1)

  it "should create grouping uses container element", ->
    o = (yang schema) top: user: {}
    o.top.should.have.property('user').and.have.property('bar')

  it "should check valid grouping reference during parse", ->
    invalid = """
      container top {
        grouping foo {
          leaf bar;
        }
        container user {
          uses nofoo;
        }
      }
      """
    (-> yang.parse invalid).should.throw()

describe 'refine schema', ->
  schema = """
    container top {
      description "grouping refine test";
      grouping foo {
        leaf bar;
      }
      container user {
        uses foo {
          refine 'bar' {
            config false;
            description "refined bar description";
          }
        }
        leaf name { type string; }
        leaf active { type boolean; }
      }
    }
    """
  it "should parse grouping refine container statement", ->
    y = yang.parse schema
    y.grouping.should.be.instanceOf(Array).and.have.length(1)
    bar = y.locate('user/bar')
    bar.should.have.property('config').property('tag').equal(false)

  
describe 'augment schema', ->
  schema = """
    container top {
      description "grouping augment test";
      grouping foo {
        container bar;
      }
      container user {
        uses foo {
          augment 'bar' {
            description "refined bar description";
            leaf extra;
          }
        }
        leaf name { type string; }
        leaf active { type boolean; }
      }
    }
    """
  it "should parse grouping augment container statement", ->
    y = yang.parse schema
    y.grouping.should.be.instanceOf(Array).and.have.length(1)
    bar = y.locate('user/bar')
    bar.should.have.property('leaf')

  
