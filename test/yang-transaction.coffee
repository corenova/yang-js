should = require 'should'

describe "YANG commit/revert transactions", ->

  describe "list transaction", ->
    schema = """
      container foo {
        list x {
          key a;
          leaf a {
            type uint8;
          }
          leaf b {
            type string;
          }
        }
      }
    """
    it "should revert back to uninitialized state", ->
      o = (Yang.parse schema) foo: x: [ { a: 1 }, { a: 2 } ]
      await o.foo.revert()
      should.not.exist(o.foo)

    it "should revert back to prior state after merge", ->
      o = (Yang.parse schema) foo: x: [ { a: 1, b: 'hi' }, { a: 2 } ]
      await o.foo.commit()
      o.foo.merge x: [ { a: 1, b: 'bye' }, { a: 2, b: 'bogus' } ]
      await o.foo.revert()
      o.foo.x.should.be.instanceOf(Array).and.have.length(2)
      o.foo.x.get('key(1)').should.have.property('b').and.equal('hi')
      #console.warn(o.foo.x.toJSON())
    
    it "should revert back to prior state after merge and creates", ->
      o = (Yang.parse schema) foo: x: [ { a: 1 }, { a: 2 } ]
      await o.foo.commit()
      o.foo.merge x: [ { a: 1, b: 'hi' }, { a: 2, b: 'bye' }, { a: 3 } ]
      await o.foo.revert()
      o.foo.x.should.be.instanceOf(Array).and.have.length(2)
    
    it "should revert back to prior state after set/replace", ->
      o = (Yang.parse schema) foo: x: [ { a: 1 }, { a: 2 } ]
      await o.foo.commit()
      o.foo.x = [ { a: 1, b: 'hi' }, { a: 2, b: 'bye' }, { a: 3 } ]
      await o.foo.revert()
      o.foo.x.should.be.instanceOf(Array).and.have.length(2)
    

    
    
    
    
  
