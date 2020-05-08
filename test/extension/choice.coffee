should = require 'should'

describe 'simple schema', ->
  schema = 'choice foo;'

  it "should parse simple choice statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo')

describe 'extended schema', ->
  schema = """
    choice foo {
      case a {
        leaf bar1;
      }
      case b {
        leaf bar2;
      }
      default a;
    }
  """
  it "should parse extended choice statement", ->
    y = Yang.parse schema
    y.case.should.be.instanceOf(Array).and.have.length(2)

  it "should create extended choice element (default a)", ->
    o = (Yang.parse schema)()
    o.should.have.property('bar1')

  it "should select case b choice element", ->
    o = (Yang.parse schema) bar2: 'hi'
    o.should.have.property('bar2')
    o.should.not.have.property('bar1')

describe 'without case', ->
  schema = """
    choice foo {
      container bar {
        leaf a;
        leaf b;
      }
    }
  """
  it "should parse choice statement without case", ->
    y = Yang.parse schema
    y.case.should.have.length(1)
  
describe 'invalid schema', ->

  it "should reject more than one non-case data node", ->
    (-> Yang.parse 'choice foo { leaf a; leaf b }' ).should.throw()

  it "should reject default and mandatory set at same time", ->
    (-> Yang.parse 'choice foo { mandatory true; default a; }' ).should.throw()

  it "should reject default without matching case", ->
    (-> Yang.parse 'choice foo { default a; }' ).should.throw()
