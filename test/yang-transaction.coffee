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
    
  describe "concurrent transaction", ->
    schema = """
      container foo {
        container a {
          leaf a1;
          leaf a2;
        }
        container b {
          leaf b1;
          leaf b2;
        }
      }
    """
    it "should complete parallel transactions on same node", ->
      o = (Yang.parse schema)
        .bind { commit: (ctx) ->
          # console.warn('commit fired...');
          await ctx.after 100
          # console.warn('commit done...');
        }
        .eval foo: { a: a1: 'hi' }
      # console.warn('initial commit started');
      promise = o.foo.commit() # asynchronous commit
      await o.foo._context.after 10
      o.foo._changes.length.should.equal(1) # one pending change
      # console.warn('pushing b');
      await o.foo._context.push b: b1: 'there'
      # console.warn('pushed b');
      # console.warn(o.foo._changes.length)
      await promise
      o.foo._changes.length.should.equal(0)

    it "should complete parallel transactions on peer nodes", ->
      o = (Yang.parse schema)
        .bind { commit: (ctx) ->
          # console.warn('commit fired...');
          await ctx.after 100
          # console.warn('commit done...');
        }
        .eval foo: {
          a: a1: 'hi'
          b: b1: 'there'
        }
      # console.warn('initial commit started');
      await o.foo.commit() # asynchronous commit

      # console.warn('parallel push to a and b');
      p1 = o.foo.a._context.push a1: 'merry'
      p2 = o.foo.b._context.push b1: 'christmas'

      # at first there should be no changes detected on o.foo
      o.foo._changes.length.should.equal(0);
      await o.foo._context.after 10
      o.foo._changes.length.should.equal(2);
      await p1
      o.foo._changes.length.should.equal(1);
      await p2
      o.foo._changes.length.should.equal(0);



    
    
    
  
