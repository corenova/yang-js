should = require 'should'

describe 'bits', ->
  schema = """
    type bits {
      bit one {
        position 0;
      }
      bit two;
      bit three;
    }
  """
  it "should parse type bits statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('bits')
    y.bit.should.be.instanceOf(Array).and.have.length(3)

describe 'boolean', ->
  schema = undefined

  before ->
    schema = Yang.parse 'leaf foo { type boolean; }';

  it "should validate boolean value", ->
    o = schema()
    (-> o.foo = 'yes').should.throw()
    (-> o.foo = 'True').should.throw()
    (-> o.foo = 1).should.throw()
    (-> o.foo = 0).should.throw()
    (-> o.foo = 'true').should.not.throw()
    (-> o.foo = true).should.not.throw()
    (-> o.foo = false).should.not.throw()

  it "should convert input to boolean value", ->
    o = schema()
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
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 'lemon').should.throw()
    (-> o.foo = 3).should.throw()
    (-> o.foo = '1').should.throw()
    (-> o.foo = 'apple').should.not.throw()
    (-> o.foo = '0').should.not.throw()
    (-> o.foo = 21).should.not.throw()

describe 'string', ->
  schema = """
    type string {
      length 2..5;
      pattern '[a-z]+';
    }
    """
  it "should parse type string statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('string')
    y.length.should.have.property('tag').and.equal('2..5')
    y.pattern.should.be.instanceOf(Array).and.have.length(1)

  it "should parse multi-line regexp pattern", ->
    y = Yang.parse """
      type string {
        pattern
          '[a-z]+'
        + '[0-9]+';
      }
      """
    y.resolve()
    y.pattern.should.be.instanceof(Array)
    y.pattern[0].should.have.property('tag').and.be.instanceof(RegExp)
    should(y.pattern[0].tag.toString()).equal('/^(?:[a-z]+[0-9]+)$/')

  it "should parse special escape regexp pattern", ->
    y = Yang.parse 'type string { pattern "\\d+"; }'
    y.pattern[0].should.have.property('tag').and.be.instanceof(RegExp)
    y.pattern[0].tag.test(123).should.equal(true)
    y.pattern[0].tag.test('hi').should.equal(false)

  it "should validate length constraint", ->
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 'x').should.throw()
    (-> o.foo = 'xxxxxxxxxx').should.throw()

  it "should validate pattern constraint", ->
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 'app1').should.throw()
    (-> o.foo = 'Apple').should.throw()
    (-> o.foo = 'abc').should.not.throw()

  it "should validate multi-pattern constraint", ->
    schema = """
      type string {
        length 1..5;
        pattern '[a-z]+';
        pattern 'x.+';
      }
      """
    o = (Yang.parse "leaf foo { #{schema} }")()
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
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '123abc').should.throw()
    (-> o.foo = 7).should.not.throw()
    (-> o.foo = '777').should.not.throw()

  it "should validate range constraint", ->
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 0).should.throw()
    (-> o.foo = 11).should.throw()
    (-> o.foo = 99).should.throw()
    (-> o.foo = 1001).should.throw()

  it "should validate unsigned integers", ->
    o = (Yang.parse "leaf foo { type uint8; }")()
    (-> o.foo = 0).should.not.throw()
    (-> o.foo = 1).should.not.throw()
    (-> o.foo = 255).should.not.throw()
    (-> o.foo = -1).should.throw()
    (-> o.foo = 256).should.throw()

  it "should validate signed integers", ->
    o = (Yang.parse "leaf foo { type int8; }")()
    (-> o.foo = 0).should.not.throw()
    (-> o.foo = 1).should.not.throw()
    (-> o.foo = -1).should.not.throw()
    (-> o.foo = 127).should.not.throw()
    (-> o.foo = 128).should.throw()
    (-> o.foo = -129).should.throw()

describe 'decimal64', ->
  it "should convert/validate input as decimal64", ->
    o = (Yang.parse 'leaf foo { type decimal64; }')()
    (-> o.foo = 'abc').should.throw()
    (-> o.foo = '').should.not.throw()
    (-> o.foo = '0.').should.not.throw()
    (-> o.foo = '0.0').should.not.throw()
    (-> o.foo = 0).should.not.throw()
    (-> o.foo = '1.3').should.not.throw()
    (-> o.foo = 1.2).should.not.throw()
    (-> o.foo = '1.3134').should.throw()
    (-> o.foo = 1.2345).should.throw()
    
  it "should validate range constraint", ->
    o = (Yang.parse "leaf foo { type decimal64 { range '-10..5.34'; } }")()
    (-> o.foo = 0).should.not.throw()
    (-> o.foo = -9).should.not.throw()
    (-> o.foo = 5).should.not.throw()
    (-> o.foo = 6).should.throw()
    (-> o.foo = -10.1).should.throw()

  it "should convert to fraction-digits constraint", ->
    o = (Yang.parse "leaf foo { type decimal64 { fraction-digits 3; } }")()
    o.foo = "1.234"
    o.foo.should.equal(1.234)
    o.foo = 125.2
    o.foo.should.equal(125.200)

# TODO
describe "binary", ->
  
describe "empty", ->
  it "should convert/validate input as empty", ->
    o = (Yang.parse 'leaf foo { type empty; }')()
    (-> o.foo = null).should.not.throw()
    (-> o.foo = [null]).should.not.throw()
    (-> o.foo = 'bar').should.throw()
    
describe "identityref", ->
  schema = undefined
  it "should parse identityref statement", ->
    schema = Yang.parse """
    module foo {
      identity my-id;
      identity my-sub-id { base my-id; }
      identity my-sub-sub-id { base my-sub-id; }
      leaf a { type identityref { base my-id; } }
      leaf b { type identityref { base my-sub-id; } }
    }
    """
    schema.should.have.property('identity').and.be.instanceof(Array)

  it "should create identityref element", ->
    o = schema()
    o.get('/').should.have.property('foo:a')

  it.skip "should validate identityref element", ->
    (-> schema 'foo:a': 'my-id').should.not.throw()
    (-> schema 'foo:a': 'my-sub-id').should.not.throw()
    (-> schema 'foo:b': 'my-sub-sub-id').should.not.throw()
    (-> schema 'foo:a': 'invalid').should.throw()
  
describe "instance-identifier", ->
  schema = undefined
  it "should parse instance-identifier statement", ->
    schema = Yang.parse """
    module foo {
      leaf a;
      leaf b { type instance-identifier; }
    }
    """
    schema.should.have.property('leaf').and.be.instanceof(Array)

  it "should create instance-identifier element", ->
    o = schema()
    o.get('/').should.have.property('foo:b')

  it "should validate instance-identifier element", ->
    (-> schema 'foo:b': '/foo:a' ).should.not.throw()
    (-> schema 'foo:b': '/foo:c' ).should.throw()

describe "require-instance", ->
  schema = undefined
  it "should parse require-instance statement", ->
    schema = Yang.parse """
    module foo {
      leaf a;
      leaf b {
        type instance-identifier {
          require-instance true;
        }
      }
    }
    """
    schema.should.have.property('leaf').and.be.instanceof(Array)

  it "should validate require-instance parameter", ->
    (-> schema 'foo:a': 1, 'foo:b': '/foo:a' ).should.not.throw()
  
describe "leafref", ->
  schema = undefined
  it "should parse leafref statement", ->
    schema = Yang.parse """
    container foo {
      leaf bar1 { type string; }
      leaf bar2 {
        type leafref { path '../bar1'; }
      }
    }
    """
    schema.should.have.property('leaf').and.be.instanceof(Array)
    schema.lookup('leaf','bar2').should.have.property('type')

  it "should create leafref element", ->
    o = schema()
    o.should.have.property('foo')

  it "should validate leafref element", ->
    o = schema foo: bar1: 'exists'
    (-> o.foo.bar2 = 'dummy').should.throw()
    (-> o.foo.bar2 = 'exists').should.not.throw()
  
describe "union", ->
  schema = """
    type union {
      type string { length 1..5; }
      type uint8;
    }
    """
  schema2 = """
    type union {
      type string {
        length 1..3;
        pattern '[a-fA-F0-9]*';
      }
      type string {
        length 6;
        pattern '[a-fA-F0-9]*';
      }
    }
    """
  it "should parse union statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.be.equal('union')
    y.type.should.be.instanceof(Array)

  it "should convert/validate union type element", ->
    o = (Yang.parse "leaf foo { #{schema} }")()
    (-> o.foo = 'abcdefg').should.throw()
    (-> o.foo = 'a').should.not.throw()
    (-> o.foo = 123).should.not.throw()
    (-> o.foo = 12345).should.not.throw()

  it "should parse multiple primitives", ->
    y = Yang.parse schema2
    o = Yang.parse("leaf foo { #{schema2} }")()
    (-> o.foo = '').should.throw()
    (-> o.foo = 'abc').should.not.throw()
    (-> o.foo = 'Abcde1').should.not.throw()
  
describe 'typedef', ->
  schema = """
    module A {
      typedef t_A {
        type union {
          type string {
            length 4;
          }
          type string {
            length 6;
          }
        }
      }
      leaf foo {
        type t_A {
          length 3;
        }
      }
    }
    """

  it "should parse complex typedef statement", ->
    y = Yang.parse schema
    y.locate('leaf(foo)').should.have.property('type')
  
