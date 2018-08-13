should = require 'should'

describe "leafref", ->
    describe "require-instance", ->
      schema = """
        container foo {
          leaf bar1 { type string; }
          leaf bar2 {
            type leafref {
              path '../bar1';
              require-instance false;
            }
          }
          leaf bar3 {
            type leafref {
              path '../bar1';
              require-instance true;
            }
          }
        }
        """
      it "should parse require-instance statement", ->
        y = Yang schema
        y.should.have.property('leaf').and.be.instanceof(Array)

      it "should validate require-instance parameter", ->
        o = (Yang schema)
          foo: bar1: 'exists'
        (-> o.foo.bar2 = 'dummy').should.not.throw()
        (-> o.foo.bar3 = 'dummy').should.throw()
