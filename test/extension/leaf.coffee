describe 'simple schema', ->
  schema = 'leaf foo;'

  it "should parse simple leaf statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple leaf element", ->
    o = (yang schema) foo: 'hello'
    o.should.have.property('foo').and.equal('hello')
    o.foo = 'bye'
    o.foo.should.equal('bye')

describe 'extended schema', ->
  schema = """
    leaf foo {
      description "extended leaf foo";
      default "bar";
    }
    """
  it "should parse extended leaf statement", ->
    y = yang.parse schema
    y.default.should.have.property('tag').and.equal('bar')

  it "should create extended leaf element", ->
    o = (yang schema)()
    o.should.have.property('__')

  it "should contain default leaf value", ->
    o = (yang schema)()
    o.foo.should.equal(o.__.foo.schema.default.tag)

  it "should not allow mandatory and default at the same time", ->
    schema = """
      leaf foo {
        mandatory true;
        default "bar";
      }
      """
    (-> yang.parse(schema).resolve() ).should.throw()

  it "should enforce mandatory leaf", ->
    schema = """
      leaf foo {
        mandatory true;
      }
      """
    (-> (yang schema)()).should.throw()
    (-> (yang schema) foo: undefined).should.throw()
    (-> (yang schema) foo: 'bar').should.not.throw()

  it "should enforce config false (readonly)", ->
    schema = """
      leaf foo {
        config false;
      }
      """
    (-> (yang schema) foo: 'hi').should.throw()

  it "should allow assigning computed function", ->
    schema = """
      leaf foo {
        config false;
      }
      """
    (-> (yang schema) foo: -> 'bar').should.not.throw()
    o = (yang schema) foo: -> 'bar'
    o.foo.should.equal('bar')

describe 'typed schema', ->
  schema = 'leaf foo { type string; }'
  it "should parse type extended leaf statement", ->
    y = yang.parse schema
    y.type.should.have.property('tag').and.equal('string')

  it "should create type extended leaf element", ->
    o = (yang schema) foo: 'hello'
    o.should.have.property('foo')

  it "should validate type on computed function result", ->
    schema = """
      leaf foo {
        type int8;
        config false;
      }
      """
    (->
      o = (yang schema) foo: -> 123
      o.foo
    ).should.not.throw()
    (->
      o = (yang schema) foo: -> 'bar'
      o.foo
    ).should.throw()
      
    
    
