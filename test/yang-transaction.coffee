should = require 'should'

describe "YANG commit/revert transactions", ->
  schema = """
    container bar {
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

  describe "list transaction", ->
    it "should revert back to uninitialized state", ->
      o = (Yang.parse schema) bar: x: [ { a: 1 }, { a: 2 } ]
      await o.bar.revert()
      should.not.exist(o.bar)

    it "should revert back to prior state after merge", ->
      o = (Yang.parse schema) bar: x: [ { a: 1 }, { a: 2 } ]
      await o.bar.commit()
      console.warn('COMMIT DONE');
      o.bar.merge x: [ { a: 1, b: 'hi' }, { a: 2, b: 'bye' } ]
      await o.bar.revert()
      o.bar.x.should.be.instanceOf(Array).and.have.length(2)
      #console.warn(o.bar.x.toJSON())
    
    it "should revert back to prior state after merge and creates", ->
      o = (Yang.parse schema) bar: x: [ { a: 1 }, { a: 2 } ]
      await o.bar.commit()
      o.bar.merge x: [ { a: 1, b: 'hi' }, { a: 2, b: 'bye' }, { a: 3 } ]
      await o.bar.revert()
      o.bar.x.should.be.instanceOf(Array).and.have.length(2)
      #console.warn(o.bar.x.toJSON())
    
    it "should revert back to prior state after set/replace", ->
      o = (Yang.parse schema) bar: x: [ { a: 1 }, { a: 2 } ]
      await o.bar.commit()
      o.bar.x = [ { a: 1, b: 'hi' }, { a: 2, b: 'bye' }, { a: 3 } ]
      await o.bar.revert()
      console.warn(o.bar.x)
      o.bar.x.should.be.instanceOf(Array).and.have.length(2)
      console.warn(o.bar.x.toJSON())
    

    
    
    
    
  
