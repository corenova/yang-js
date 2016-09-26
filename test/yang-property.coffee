global.Yang = require '..'

describe "YANG Property Implementation:", ->

  describe "property without schema", ->
    property = undefined
    it "should create basic property", ->
      property = new Yang.Model.Property 'test'
      property.should.have.property('name').and.equal('test')

    it "should initialize array property", ->
      property.set []
      property.get().should.be.instanceof(Array)

    it "should join arbitrary object", ->
      o = property.join {}
      o.should.have.property('test')

  describe "property with schema", ->

    it "should create basic property", ->
      schema = Yang.parse('leaf foo;')
      property = new Yang.Model.Property 'test', schema
      
      

    
      
