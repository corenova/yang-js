describe 'boolean', ->
  schema = 'leaf foo { type boolean; }'

  it "should validate boolean value", ->
    o = (yang schema)()
    (-> o.foo = 'yes').should.throw()
    (-> o.foo = 'True').should.throw()
    (-> o.foo = 'true').should.not.throw()
    (-> o.foo = true).should.not.throw()
    (-> o.foo = 1).should.not.throw()

  it "should convert input to boolean value", ->
    o = (yang schema)()
    o.foo = 'true';    o.foo.should.equal(true)
    o.foo = true;      o.foo.should.equal(true)
    o.foo = 123;       o.foo.should.equal(true)
    o.foo = 'false';   o.foo.should.equal(false)
    o.foo = false;     o.foo.should.equal(false)
    o.foo = 0;         o.foo.should.equal(false)

describe 'enumeration', ->
  schema = """
    type enumeration {
      enum apple;
      enum orange { value 20; }
      enum banana;
    }
    """
  it "should parse type enumeration statement", ->
    y = yang.parse schema
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
    o = (yang "leaf foo { #{schema} }")()
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
      pattern '[a-z]+';
      pattern '^x';
    }
    """
  it "should parse type string statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('string')
    y.length.should.have.property('tag').and.equal('1..5')
    y.pattern.should.be.instanceOf(Array).and.have.length(2)

  it "should validate length constraint", ->
    o = (yang "leaf foo { #{schema} }")()
    (-> o.foo = '').should.throw()
    (-> o.foo = 'xxxxxxxxxx').should.throw()

  it "should validate pattern constraint", ->
    o = (yang "leaf foo { #{schema} }")()
    (-> o.foo = 'apple').should.throw()
    (-> o.foo = 'XYZ').should.throw()
    (-> o.foo = 'xxx').should.not.throw()

describe 'number', ->
  schema = """
    type number {
      range '1..10|100..1000';
    }
    """
  it "should parse type number statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.equal('number')
    y.range.should.have.property('tag').and.equal('1..10|100..1000')

  it "should validate input as number", ->
    o = (yang "leaf foo { #{schema} }")()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '123abc').should.throw()
    (-> o.foo = 7).should.not.throw()
    (-> o.foo = '777').should.not.throw()

  it "should validate range constraint", ->
    o = (yang "leaf foo { #{schema} }")()
    (-> o.foo = 0).should.throw()
    (-> o.foo = 11).should.throw()
    (-> o.foo = 99).should.throw()
    (-> o.foo = 1001).should.throw()

  # TODO add cases for int8, int16, uint8, etc...

describe 'decimal64', ->
  it "should convert/validate input as decimal64", ->
    o = (yang 'leaf foo { type decimal64; }')()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '').should.not.throw()
    (-> o.foo = '1.3459').should.not.throw()
    (-> o.foo = 1.2345).should.not.throw()

# TODO
describe "binary", ->
describe "empty", ->
describe "identityref", -> 
describe "instance-identifier", ->
  
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
    y = yang.parse schema
    y.should.have.property('leaf').and.be.instanceof(Array)
    y.lookup('leaf','bar2').should.have.property('type')

  it "should create leafref element", ->
    o = (yang schema)()
    o.should.have.property('foo')

  it "should validate leafref element", ->
    o = (yang schema)
      foo: bar1: 'exists'
    o.foo.bar2 = 'dummy'
    o.foo.bar2.should.be.instanceof(Error)
    o.foo.bar2 = 'exists'
    o.foo.bar2.should.not.be.instanceof(Error)
  
describe "union", ->
  schema = """
    type union {
      type string { length 1..5; }
      type uint8;
    }
    """
  it "should parse union statement", ->
    y = yang.parse schema
    y.should.have.property('tag').and.be.equal('union')
    y.type.should.be.instanceof(Array)

  it "should convert/validate union type element", ->
    o = (yang "leaf foo { #{schema} }")()
    (-> o.foo = 'abcdefg').should.throw()
    (-> o.foo = 'a').should.not.throw()
    (-> o.foo = 123).should.not.throw()
    (-> o.foo = 12345).should.not.throw()

  
