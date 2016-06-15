describe 'simple schema', ->
  schema = 'list foo;'

  it "should parse simple list statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple list element", ->
    o = (yang schema) foo: [ bar: 'hello' ]
    o.should.have.property('foo').and.be.instanceOf(Array)
    o.foo.should.have.length(1)

  it "should allow setting a new list", ->
    o = (yang schema)()
    o.foo = [ { bar1: 'hello' }, { bar2: 'world' } ]
    o.foo.should.be.instanceOf(Array).and.have.length(2)

  it.skip "should allow adding additional items to the list", ->
    # o = yang(schema).create()
    # o.foo = 'hello'
    # o.foo.should.be.instanceOf(Array).and.have.length(1)
    # o.foo = 'world'
    # o.foo.should.be.instanceOf(Array).and.have.length(2)

describe 'extended schema', ->
  schema = """
    list foo {
      description "extended list foo";
      min-elements 1;
      max-elements 3;
    }
    """
  it "should parse extended list statement", ->
    y = yang.parse schema
    y['min-elements'].should.have.property('tag').and.equal(1)
    y['max-elements'].should.have.property('tag').and.equal(3)

  it "should create extended list element", ->
    o = (yang schema) foo: [ bar: 'hello' ]
    o.foo.should.be.instanceOf(Array).and.have.length(1)

  it "should reject non-object list element", ->
    (-> (yang schema) foo: [ 'not an object' ]).should.throw()

  it "should validate min/max elements constraint", ->
    o = (yang schema) foo: [ bar: 'hello' ]
    (-> o.foo = []).should.throw()
    (-> o.foo = [ {}, {}, {}, {} ]).should.throw()
    (-> o.foo = [ {}, {}, {} ]).should.not.throw()

  it.skip "should support order-by condition", ->

  it "should enforce key/leaf mapping during parse", ->
    schema = """
      list foo {
        key 'bar';
      }
    """
    (-> yang.parse schema ).should.throw()

  it "should enforce unique/leaf mapping during parse", ->
    schema = """
      list foo {
        unique 'bar';
      }
    """
    (-> yang.parse schema ).should.throw()

describe 'complex schema', ->
  schema = """
    list foo {
      key 'bar1 bar2';
      unique 'bar2 bar3';
      leaf bar1 { type string; }
      leaf bar2 { type int8; }
      leaf bar3 { type string; }
      container name {
        leaf first;
        leaf last;
      }
      leaf-list friends { type string; }
    }
    """
  it "should parse complex list statement", ->
    y = yang.parse schema
    y.key.should.have.property('tag').and.be.instanceof(Array)

  it "should create complex list element", ->
    o = (yang schema)()
    o.should.have.property('foo')

  it "should support key based list access", ->
    o = (yang schema) foo: [
      bar1: 'apple'
      bar2: 10
     ,
      bar1: 'apple'
      bar2: 20
    ]
    o.foo.should.have.property('apple,10')

  it "should not allow conflicting key", ->
    (->
      (yang schema) foo: [
        bar1: 'apple'
        bar2: 10
       ,
        bar1: 'apple'
        bar2: 10
      ]
    ).should.throw()

  it "should validate unique constraint", ->
    (->
      (yang schema) foo: [
        bar1: 'apple'
        bar2: 10
        bar3: 'conflict'
       ,
        bar1: 'orange'
        bar2: 10
        bar3: 'conflict'
      ]
    ).should.throw()

