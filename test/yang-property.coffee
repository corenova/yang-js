global.Yang = require '..'

describe "YANG Property Implementation:", ->

  describe "property without schema", ->
    property = undefined
    it "should create basic property", ->
      property = new Yang.Property 'test'
      property.should.have.property('name').and.equal('test')

    it "should initialize array property", ->
      property.set []
      property.get().should.be.instanceof(Array)

    it "should join arbitrary object", ->
      o = property.attach {}
      o.should.have.property('test')

  describe "property with schema", ->

    it "should create basic property", ->
      property = new Yang.Property 'test',
        kind: 'leaf'
      
