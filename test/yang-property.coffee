global.Yang = require '..'

describe "YANG Property Implementation:", ->

  describe "property without schema", ->
    property = undefined
    it "should create basic property", ->
      property = new Yang.Property name: 'test'
      property.should.have.property('name').and.equal('test')

    it "should initialize array property", ->
      property.set []
      property.get().should.be.instanceof(Array)

    it "should join arbitrary object", ->
      o = property.attach {}
      o.should.have.property('test')

  describe "property with schema", ->

    it "should create basic property", ->
      property = new Yang.Property name: 'test', schema: kind: 'leaf'
      
  describe "property memory profile", ->

    it "should have minimal memory footprint", ->
      pre = process.memoryUsage()
      a = Array(10000).fill(null).map( () -> new Yang.Container )
      post = process.memoryUsage()
      growth = (post.heapUsed - pre.heapUsed) / 1024
      

      
