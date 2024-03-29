describe 'simple schema', ->
  schema = 'list foo;'

  it "should parse simple list statement", ->
    y = Yang.parse schema
    y.should.have.property('tag').and.equal('foo')

  it "should create simple list element", ->
    o = (Yang.parse schema) foo: [ bar: 'hello' ]
    o.should.have.property('foo').and.be.instanceOf(Array)
    o.foo.should.have.length(1)

  it "should allow setting a new list", ->
    o = (Yang.parse schema)()
    o.foo = [ { bar1: 'hello' }, { bar2: 'world' } ]
    o.foo.should.be.instanceOf(Array).and.have.length(2)

  it "should allow adding additional items to the list", ->
    o = (Yang.parse schema) foo: []
    o.foo.merge a: 'hi'
    o.foo.should.be.instanceOf(Array).and.have.length(1)
    o.foo.merge a: 'bye'
    o.foo.should.be.instanceOf(Array).and.have.length(2)

describe 'extended schema', ->
  schema = """
    list foo {
      description "extended list foo";
      min-elements 1;
      max-elements 3;
    }
    """
  it "should parse extended list statement", ->
    y = Yang.parse schema
    y['min-elements'].should.have.property('tag').and.equal(1)
    y['max-elements'].should.have.property('tag').and.equal(3)

  it "should create extended list element", ->
    o = (Yang.parse schema) foo: [ bar: 'hello' ]
    o.foo.should.be.instanceOf(Array).and.have.length(1)

  it "should reject non-object list element", ->
    (-> (Yang.parse schema) foo: [ 'not an object' ]).should.throw()

  it "should validate min/max elements constraint", ->
    o = (Yang.parse schema) foo: [ bar: 'hello' ]
    (-> o.foo = []).should.throw()
    (-> o.foo = [ {}, {}, {}, {} ]).should.throw()
    (-> o.foo = [ {}, {}, {} ]).should.not.throw()

  it.skip "should support order-by condition", ->

  it "should enforce key/leaf mapping during resolve", ->
    schema = """
      list foo {
        key 'bar';
      }
    """
    (-> Yang.parse schema ).should.throw()

  it "should enforce unique/leaf mapping during resolve", ->
    schema = """
      list foo {
        unique 'bar';
      }
    """
    (-> Yang.parse schema ).should.throw()

describe 'complex schema', ->
  schema = """
    list foo {
      key 'bar1 bar2';
      unique 'bar2 name/first';
      leaf bar1 { type string; }
      leaf bar2 { type int8; }
      leaf bar3 { type string; }
      container name {
        leaf first;
        leaf last;
      }
      leaf-list friends { type string; }
    }
   """
  it "should parse complex list statement", ->
    y = Yang.parse schema
    y.key.should.have.property('tag').and.be.instanceof(Array)

  it "should create complex list element", ->
    o = (Yang.parse schema)()
    o.should.have.property('foo')

  it "should support key based list access", ->
    o = (Yang.parse schema) foo: [
      bar1: 'apple'
      bar2: 10
     ,
      bar1: 'apple'
      bar2: 20
    ]
    o.foo.get('key(apple,10)').should.have.property('bar1')

  it "should not allow conflicting key", ->
    (->
      (Yang.parse schema) foo: [
        bar1: 'apple'
        bar2: 10
       ,
        bar1: 'apple'
        bar2: 10
      ]
    ).should.throw()
    
    o = (Yang.parse schema) foo: [
      bar1: 'apple'
      bar2: 10
    ]
    (->
      o.foo.create
        bar1: 'apple'
        bar2: 10
    ).should.throw()

  it.skip "should validate nested unique constraint", ->
    (->
      (Yang.parse schema) foo: [
        bar1: 'apple'
        bar2: 10
        name: first: 'conflict'
       ,
        bar1: 'orange'
        bar2: 10
        name: first: 'conflict'
      ]
    ).should.throw()

  it "should support merge operation", ->
    o = (Yang.parse schema) foo: [
      bar1: 'apple'
      bar2: 10
    ]
    o.foo.merge
      bar1: 'apple'
      bar2: 10
      bar3: 'test'
    o.foo.get('key(apple,10)').should.have.property('bar3').and.equal('test')

  it "should support delete operation", ->
    o = (Yang.parse schema) foo: [
      bar1: 'apple'
      bar2: 10
    ,
      bar1: 'apple'
      bar2: 20
    ,
      bar1: 'orange'
      bar2: 3
    ]
    o.foo.should.have.length(3);
    delete o.foo['key(apple,10)'];
    o.foo.should.have.length(2);
    o.foo['key(apple,20)'] = null
    o.foo.should.have.length(1);
    o.foo['key(orange,3)'].merge(null)
    o.foo.should.have.length(0);

describe 'edge cases', ->
  schema = """
    module m1 {
      grouping g1 { leaf id; }
      // key declared before uses where the leaf is
      list foo {
        key "id";
        uses g1;
        leaf ref {
          type leafref {
            path "../../bar";
          }
        }
      }
      leaf bar;
    }
    """
  it "should resolve 'key' reference to used grouping", ->
    (-> Yang.parse schema ).should.not.throw()

  it "should properly traverse relative leafref path", ->
    (->
      (Yang.parse schema) 'm1:bar': 'hello', 'm1:foo': [
        id: 1
        ref: 'hello'
      ]
    ).should.not.throw()

describe 'performance', ->
  schema = """
    list foo {
      key id;
      leaf id {
        type uint16;
      }
      container bar {
        leaf v1 {
          type uint32;
        }
        leaf v2 {
          type uint32;
        }
      }
    }
    """
  model = undefined
  filler = (_,i) -> { id: i, bar: { v1: i*123, v2: i*321 } }
  d100 = Array(100).fill(null).map filler
  d500 = Array(500).fill(null).map filler
  
  before ->
    model = (Yang.parse schema).eval()

  it "time setting 100 entries", ->
    model.foo = d100

  it "time setting 500 entries", ->
    model.foo = d500
  
  it "time merging one existing item into 500 entries", ->
    pre = process.memoryUsage()
    model.foo.merge({ id: 1 })
    post = process.memoryUsage()
    # console.log("growth: %d KB", (post.heapUsed - pre.heapUsed) / 1024);    
    model.foo.should.be.instanceof(Array).and.have.length(500)

  it "time setting 1000 entries to large list", ->
    model.foo = Array(1000).fill(null).map(filler)

  it "time merging an existing entry to large list", ->
    one = Array(1).fill(null).map filler
    pre = process.memoryUsage()
    model.foo.merge(one);
    #model.foo.merge([{ id: 1, bar: { v1: 30, v2: 50 } }]);
    post = process.memoryUsage()
    console.log("mem growth: %d KB", (post.heapUsed - pre.heapUsed) / 1024);    
    
  it "time merging existing 1000 entries to large list", ->
    many = Array(1000).fill(null).map(filler)
    pre = process.memoryUsage()
    for i in [0...10] by 1
      model.foo.merge(many, { appendOnly: true });
      #model.foo.merge(many);
    post = process.memoryUsage()
    growth = (post.heapUsed - pre.heapUsed) / 1024
    console.error("mem growth: %d KB", growth);

    
