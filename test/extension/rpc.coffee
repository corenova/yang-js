describe 'simple schema', ->
  schema = 'rpc foo;'

  it "should parse simple rpc statement", ->
    y = yang.parse schema
    y.should.have.property('kind').and.equal('rpc')

  it "should create simple rpc element", ->
    o = (yang schema) foo: (input,resolve,reject) -> resolve 'bye'
    o.should.have.property('foo').and.be.instanceof(Function)
    o.foo ''
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
    y = yang.parse schema
    y.input.should.have.property('leaf')

  it "should create extended rpc element", ->
    o = (yang schema)()
    o.should.have.property('foo')

  it "should allow assigning handler function", ->
    (-> (yang schema) foo: ->).should.throw()
    (-> (yang schema) foo: 'error').should.throw()
    (-> (yang schema) foo: (input, resolve, reject) -> resolve message: 'ok').should.not.throw()

  it "should validate input parameters", ->
    o = (yang schema) foo: (input, resolve, reject) -> resolve message: 'ok'
    o.foo 'hello'
    .catch (err) -> err.should.be.instanceof(Error)
    o.foo bar: 'good'
    .then (res) -> res.should.have.property('message').and.is.equal('ok')

  it "should validate output parameters", ->
    o = (yang schema) foo: (input, resolve, reject) -> resolve dummy: 'bad'
    o.foo bar: 'good'
    .then  (res) -> res.should.not.have.property('dummy')
    .catch (err) -> err.should.be.instanceof(Error)
