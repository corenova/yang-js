describe 'simple schema', ->
  schema = 'rpc foo;'

  it "should parse simple rpc statement", ->
    y = Yang.parse schema
    y.should.have.property('kind').and.equal('rpc')

  it "should create simple rpc element", ->
    o = Yang.parse(schema).bind(-> @output = 'bye').eval()
    o.should.have.property('foo').and.be.instanceof(Function)
    o.foo()
    .then (res) -> res.should.equal('bye')

describe 'extended schema', ->
  schema = """
    rpc foo {
      description "input extended rpc foo";
      input {
        leaf bar { type string; }
      }
      output {
        leaf message { type string; }
      }
    }
    """
  it "should parse extended rpc statement", ->
    y = Yang.parse schema
    y.input.should.have.property('leaf')

  it "should create extended rpc element", ->
    o = (Yang schema)()
    o.should.have.property('foo')

  it "should allow assigning handler function", ->
    (-> (Yang schema) foo: 'error').should.throw()
    (-> (Yang schema) foo: ->).should.not.throw()
    (-> (Yang schema) foo: -> @output = message: 'ok').should.not.throw()

  it "should validate input parameters", ->
    o = (Yang schema) foo: -> @output = message: 'ok'
    o.foo 'hello'
    .catch (err) -> err.should.be.instanceof(Error)
    o.foo bar: 'good'
    .then (res) -> res.should.have.property('message').and.is.equal('ok')

  it "should validate output parameters", ->
    o = (Yang schema) foo: -> @output = dummy: 'bad'
    o.foo bar: 'good'
    .then  (res) -> res.should.not.have.property('dummy')
    .catch (err) -> err.should.be.instanceof(Error)
