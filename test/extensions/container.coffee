describe 'simple schema', ->
  schema = 'container foo;'

  it "should parse simple container statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple container element", ->
    o = (yang schema)()
    o.should.have.property('foo')

  it.skip "should allow setting an arbitrary object", ->
    o = (yang schema)()
    o.foo = bar: [ 'hello', 'world' ]
    o.foo.should.have.property('bar').and.be.instanceOf(Array)

  it "should validate object assignment", ->
    o = (yang schema)()
    (-> o.foo = 'hello').should.throw()
    (-> o.foo = bar: 'hello').should.not.throw()

describe 'extended schema', ->
  schema = """
    container foo {
      description "extended container test";
      leaf-list vegetables;
      leaf favorite;
    }
    """
  it "should parse extended container statement", ->
    y = yang.parse schema
    y.leaf.should.be.instanceOf(Array).and.have.length(1)

  it "should create extended container element", ->
    o = (yang schema) foo: {}
    o.foo.should.have.property('favorite')

describe 'nested schema', ->
  schema = """
    container foo {
      description "nested container test";
      container bar1 {
        leaf hello;
      }
      container bar2 {
        leaf world;
      }
    }
    """
  it "should parse nested container statement", ->
    y = yang.parse schema
    y.container.should.be.instanceOf(Array).and.have.length(2)

  it "should create nested container element", ->
    o = (yang schema) foo: {}
    o.foo.should.have.properties('bar1','bar2')

