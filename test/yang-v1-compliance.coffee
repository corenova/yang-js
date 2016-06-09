should = require 'should'

describe "YANG 1.0 (RFC-6020) Compliance:", ->
  yang = require '..'

  describe 'leaf', ->

    describe 'simple schema', ->
      schema = 'leaf foo;'

      it "should parse simple leaf statement", ->
        y = yang schema, wrap: false
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
          config true;
        }
        """
      it "should parse extended leaf statement", ->
        y = yang schema, wrap: false
        y.default.should.have.property('tag').and.equal('bar')

      it "should create extended leaf element", ->
        o = (yang schema)()
        o.should.have.property('__yang__')

      it "should contain default leaf value", ->
        o = (yang schema)()
        o.foo.should.equal(o.__yang__.foo.origin.default.tag)

      describe 'validation', ->
        it "should not allow mandatory and default", ->
          schema = """
            leaf foo {
              mandatory true;
              default "bar";
            }
            """
          (-> yang schema ).should.throw()

        it "should enforce mandatory leaf", ->
          schema = """
            leaf foo {
              mandatory true;
            }
            """
          (-> (yang schema)()).should.throw()
          (-> (yang schema) foo: undefined).should.throw()
          (-> (yang schema) foo: 'bar').should.not.throw()

    describe 'typed schema', ->
      schema = 'leaf foo { type string; }'
      it "should parse type extended leaf statement", ->
        y = yang schema, wrap: false
        y.type.should.have.property('tag').and.equal('string')

      it "should create type extended leaf element", ->
        o = (yang schema) foo: 'hello'
        o.should.have.property('foo')

  describe 'leaf-list', ->

    describe 'simple schema', ->
      schema = 'leaf-list foo;'

      it "should parse simple leaf-list statement", ->
        y = yang schema, wrap: false
        y.should.have.property('tag').and.equal('foo')

      it "should create simple leaf-list element", ->
        o = (yang schema) foo: [ 'hello' ]
        o.should.have.property('foo').and.be.instanceOf(Array)
        o.foo.should.have.length(1)
        o.foo[0].should.equal('hello')

      it "should allow setting a new list", ->
        o = (yang schema)()
        o.foo = [ 'hello', 'world' ]
        o.foo.should.be.instanceOf(Array).and.have.length(2)

      it "should allow adding additional items to the list", ->
        # o = yang(schema).create()
        # o.foo = 'hello'
        # o.foo.should.be.instanceOf(Array).and.have.length(1)
        # o.foo = 'world'
        # o.foo.should.be.instanceOf(Array).and.have.length(2)

    describe 'extended schema', ->
      schema = """
        leaf-list foo {
          description "extended leaf-list foo";
          min-elements 1;
          max-elements 5;
        }
        """
      it "should parse extended leaf-list statement", ->
        y = yang schema, wrap: false
        y['min-elements'].should.have.property('tag').and.equal(1)
        y['max-elements'].should.have.property('tag').and.equal(5)

      it "should create extended leaf-list element", ->
        o = (yang schema) foo: [ 'hello' ]
        o.foo.should.be.instanceOf(Array).and.have.length(1)

      it "should validate min/max elements constraint", ->
        o = (yang schema) foo: [ 'hello' ]
        (-> o.foo = []).should.throw()
        (-> o.foo = [ 1, 2, 3, 4, 5, 6 ]).should.throw()
        (-> o.foo = [ 1, 2, 3, 4, 5 ]).should.not.throw()

      it "should support order-by condition", ->

    describe 'typed schema', ->
      schema = """
        leaf-list foo {
          type string;
        }
        """
      it "should parse type extended leaf-list statement", ->
        y = yang schema, wrap: false
        y.type.should.have.property('tag').and.equal('string')

      it "should create type extended leaf-list element", ->
        o = (yang schema) foo: []
        o.should.have.property('foo')

  describe 'container', ->

    describe 'simple schema', ->
      schema = 'container foo;'

      it "should parse simple container statement", ->
        y = yang schema, wrap: false
        y.should.have.property('tag').and.equal('foo')

      it "should create simple container element", ->
        o = (yang schema)()
        o.should.have.property('foo')

      it.skip "should allow setting an arbitrary object", ->
        o = (yang schema)()
        o.foo = bar: [ 'hello', 'world' ]
        o.foo.should.have.property('bar').and.be.instanceOf(Array)

      it "should validate object assignment", ->
        o = (yang schema)()
        (-> o.foo = 'hello').should.throw()
        (-> o.foo = bar: 'hello').should.not.throw()

    describe 'extended schema', ->
      schema = """
        container foo {
          description "extended container test";
          leaf-list vegetables;
          leaf favorite;
        }
        """
      it "should parse extended container statement", ->
        y = yang schema, wrap: false
        y.leaf.should.be.instanceOf(Array).and.have.length(1)

      it "should create extended container element", ->
        o = (yang schema)()
        o.foo.should.have.property('favorite')

    describe 'nested schema', ->
      schema = """
        container foo {
          description "nested container test";
          container bar1 {
            leaf hello;
          }
          container bar2 {
            leaf world;
          }
        }
        """
      it "should parse nested container statement", ->
        y = yang schema, wrap: false
        y.container.should.be.instanceOf(Array).and.have.length(2)

      it "should create nested container element", ->
        o = (yang schema)()
        o.foo.should.have.properties('bar1','bar2')

  describe 'type', ->
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
        y = yang schema, wrap: false
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
        y = yang schema, wrap: false
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
        y = yang schema, wrap: false
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
    describe "union", ->

