should = require 'should'

describe 'boolean', ->
  schema = 'leaf foo { type boolean; }'

  it "should validate boolean value", ->
    o = (Yang schema)()
    (-> o.foo = 'yes').should.throw()
    (-> o.foo = 'True').should.throw()
    (-> o.foo = 1).should.throw()
    (-> o.foo = 0).should.throw()
    (-> o.foo = 'true').should.not.throw()
    (-> o.foo = true).should.not.throw()
    (-> o.foo = false).should.not.throw()

  it "should convert input to boolean value", ->
    o = (Yang schema)()
    o.foo = 'true';    o.foo.should.equal(true)
    o.foo = true;      o.foo.should.equal(true)
    o.foo = 'false';   o.foo.should.equal(false)
    o.foo = false;     o.foo.should.equal(false)

describe 'enumeration', ->
  schema = """
    type enumeration {
      enum apple;
      enum orange { value 20; }
      enum banana;
    }
    """
  it "should parse type enumeration statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('enumeration')
    y.enum.should.be.instanceOf(Array).and.have.length(3)
    for i in y.enum
      switch i.tag
        when 'apple'
          i.should.have.property('value')
          i.value.tag.should.equal('0')
        when 'orange'
          i.value.tag.should.equal('20')
        when 'banana'
          i.should.have.property('value')
          i.value.tag.should.equal('21')

  it "should validate enum constraint", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 'lemon').should.throw()
    (-> o.foo = 3).should.throw()
    (-> o.foo = '1').should.throw()
    (-> o.foo = 'apple').should.not.throw()
    (-> o.foo = '0').should.not.throw()
    (-> o.foo = 21).should.not.throw()

describe 'string', ->
  schema = """
    type string {
      length 1..5;
      pattern '^[a-z]+$';
    }
    """
  it "should parse type string statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('string')
    y.length.should.have.property('tag').and.equal('1..5')
    y.pattern.should.be.instanceOf(Array).and.have.length(1)

  it "should parse multi-line regexp pattern", ->
    y = Yang.parse """
      type string {
        pattern
          '^[a-z]+'
        + '[0-9]+$';
      }
      """
    y.resolve()
    y.pattern.should.be.instanceof(Array)
    y.pattern[0].should.have.property('tag').and.be.instanceof(RegExp)
    should(y.pattern[0].tag.toString()).equal('/^[a-z]+[0-9]+$/')

  it "should validate length constraint", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = '').should.throw()
    (-> o.foo = 'xxxxxxxxxx').should.throw()

  it "should validate pattern constraint", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 'app1').should.throw()
    (-> o.foo = 'Apple').should.throw()
    (-> o.foo = 'abc').should.not.throw()

  it "should validate multi-pattern constraint", ->
    schema = """
      type string {
        length 1..5;
        pattern '^[a-z]+$';
        pattern '^x';
      }
      """
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = 'xyz').should.not.throw()

describe 'integer', ->
  schema = """
    type uint16 {
      range '1..10|100..1000';
    }
    """
  it "should parse type integer statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('uint16')
    y.range.should.have.property('tag').and.equal('1..10|100..1000')

  it "should validate input as integer", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '123abc').should.throw()
    (-> o.foo = 7).should.not.throw()
    (-> o.foo = '777').should.not.throw()

  it "should validate range constraint", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 0).should.throw()
    (-> o.foo = 11).should.throw()
    (-> o.foo = 99).should.throw()
    (-> o.foo = 1001).should.throw()

  # TODO add cases for int8, int16, uint8, etc...

describe 'decimal64', ->
  it "should convert/validate input as decimal64", ->
    o = (Yang 'leaf foo { type decimal64; }')()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '').should.throw()
    (-> o.foo = '0.0').should.not.throw()
    (-> o.foo = 0).should.not.throw()
    (-> o.foo = '1.3459').should.not.throw()
    (-> o.foo = 1.2345).should.not.throw()

# TODO
describe "binary", ->
describe "empty", ->
describe "identityref", -> 
describe "instance-identifier", ->
  schema = """
    module foo {
      leaf a;
      leaf b { type instance-identifier; }
    }
    """
  it "should parse instance-identifier statement", ->
    y = Yang.parse schema
    y.should.have.property('leaf').and.be.instanceof(Array)

  it "should create instance-identifier element", ->
    o = (Yang schema)()
    o.get('/').should.have.property('foo:b')

  it "should validate instance-identifier element", ->
    (-> (Yang schema) 'foo:b': '/foo:a' ).should.not.throw()
    (-> (Yang schema) 'foo:b': '/foo:c' ).should.throw()
  
describe "leafref", ->
  schema = """
    container foo {
      leaf bar1 { type string; }
      leaf bar2 {
        type leafref { path '../bar1'; }
      }
    }
    """
  it "should parse leafref statement", ->
    y = Yang.parse schema
    y.should.have.property('leaf').and.be.instanceof(Array)
    y.lookup('leaf','bar2').should.have.property('type')

  it "should create leafref element", ->
    o = (Yang schema)()
    o.should.have.property('foo')

  it "should validate leafref element", ->
    o = (Yang schema)
      foo: bar1: 'exists'
    (-> o.foo.bar2 = 'dummy').should.throw()
    (-> o.foo.bar2 = 'exists').should.not.throw()
  
describe "union", ->
  schema = """
    type union {
      type string { length 1..5; }
      type uint8;
    }
    """
  it "should parse union statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.be.equal('union')
    y.type.should.be.instanceof(Array)

  it "should convert/validate union type element", ->
    o = (Yang "leaf foo { #{schema} }")()
    (-> o.foo = 'abcdefg').should.throw()
    (-> o.foo = 'a').should.not.throw()
    (-> o.foo = 123).should.not.throw()
    (-> o.foo = 12345).should.not.throw()

  
