describe 'simple schema', ->
  schema = 'leaf foo;'

  it "should parse simple leaf statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple leaf element", ->
    o = (Yang.parse schema) foo: 'hello'
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
    y = Yang.parse schema
    y.default.should.have.property('tag').and.equal('bar')

  it "should create extended leaf element", ->
    o = (Yang.parse schema)()
    o.should.have.property('foo')

  it "should contain default leaf value", ->
    o = (Yang.parse schema)()
    o.foo.should.equal('bar')

  it "should not allow mandatory and default at the same time", ->
    schema = """
      leaf foo {
        mandatory true;
        default "bar";
      }
      """
    (-> Yang.parse schema ).should.throw()

  it "should enforce mandatory leaf", ->
    schema = """
      leaf foo {
        mandatory true;
      }
      """
    (-> (Yang.parse schema)()).should.throw()
    (-> (Yang.parse schema) foo: undefined).should.throw()
    (-> (Yang.parse schema) foo: 'bar').should.not.throw()

  it "should enforce config false (readonly)", ->
    schema = """
      leaf foo {
        config false;
      }
      """
    (-> (Yang.parse schema) foo: 'hi').should.throw()

  it "should allow binding computed function", ->
    schema = """
      leaf foo {
        config false;
      }
      """
    o = Yang.parse(schema).bind( get: (ctx) -> ctx.data = 'bar').eval()
    o.foo.should.equal('bar')

describe 'typed schema', ->
  schema = 'leaf foo { type string; }'
  it "should parse type extended leaf statement", ->
    y = Yang.parse schema
    y.type.should.have.property('tag').and.equal('string')

  it "should create type extended leaf element", ->
    o = (Yang.parse schema) foo: 'hello'
    o.should.have.property('foo')

  it "should validate type on computed function result", ->
    schema = """
      leaf foo {
        type int8;
        config false;
      }
      """
    (->
      o = Yang.parse(schema).bind( get: (ctx) -> ctx.data = 123).eval()
      o.foo
    ).should.not.throw()
    (->
      o = Yang.parse(schema).bind( get: (ctx) -> ctx.data = 'bar').eval()
      o.foo
    ).should.throw()
      
    
    
