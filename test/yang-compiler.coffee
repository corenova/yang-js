should = require 'should'

describe "yang-js", ->
  yang = require '..'

  describe 'use()', ->
    it "should use simple YANG spec object", ->
      yang.use
        specification:
          test:
            extension:
              foo:
                argument: 'value'

  describe 'load()', ->
    it "should load simple YANG schema string", ->
      out = yang.load 'module test {}'
      out.resolve('test').should.have.property 'name'

  describe 'preprocess()', ->
    it "should discover new extensions", ->
      out = yang.preprocess """
        module test-preprocess {
          extension hello-1 { argument value; }
          extension hello-2 { status deprecated; }
        }
      """
      out.should.have.property 'schema'
      out.should.have.property 'map'
      out.map.resolve('extension').should.have.properties 'hello-1', 'hello-2'
