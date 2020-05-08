describe 'simple schema', ->
  schema = undefined

  it "should parse simple rpc statement", ->
    schema = Yang.parse 'rpc foo;'
    schema.should.have.property('kind').and.equal('rpc')

  it "should create simple rpc element", ->
    o = schema.bind(-> 'bye').eval()
    o.should.have.property('foo').and.be.instanceof(Function)
    o.foo()
    .then (res) -> res.should.equal('bye')

describe 'extended schema', ->
  schema = undefined
  
  it "should parse extended rpc statement", ->
    schema = Yang.parse """
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
    schema.input.should.have.property('leaf')

  it "should create extended rpc element", ->
    o = schema()
    o.should.have.property('foo')

  it "should allow assigning handler function", ->
    (-> schema foo: 'error').should.throw()
    (-> schema foo: ->).should.not.throw()
    (-> schema foo: -> message: 'ok').should.not.throw()

  it "should validate input parameters", ->
    o = (schema.bind -> message: 'ok')()
    o.foo 'hello'
    .catch (err) -> err.should.be.instanceof(Error)
    o.foo bar: 'good'
    .then (res) -> res.should.have.property('message').and.is.equal('ok')

  it "should validate output parameters", ->
    o = (schema.bind -> dummy: 'bad')()
    o.foo bar: 'good'
    .then  (res) -> res.should.not.have.property('dummy')
    .catch (err) -> err.should.be.instanceof(Error)
