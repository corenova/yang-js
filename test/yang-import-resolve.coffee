global.Yang = require '..'
should = require 'should'
path = require 'path'

describe "YANG Import/Resolve Implementation:", ->
  testdir = __dirname;

  describe "resolve", ->
    it "pre-bundled modules", ->
      match = Yang.resolve testdir, "ietf-yang-types"
      should.exist(match)

    it "explicit target module", ->
      match = Yang.resolve testdir, "example-jukebox"
      should.exist(match)

    it "explict target in dependency package", ->
      match = Yang.resolve testdir, "target-in-package"
      should.exist(match)

    it "fail if explicit target not found", ->
      (-> Yang.resolve testdir, "missing-schema").should.throw()

    it "via search in directory", ->
      match = Yang.resolve testdir, "jukebox"
      should.exist(match)

    it "via search in dependency package", ->
      match = Yang.resolve testdir, "schema-in-test1"
      should.exist(match)

    it "using specified order (.yang first)", ->
      match = Yang.resolve testdir, "schema-in-test2"
      should.exist(match)
      should(path.extname match).be.equal(".yang")
      
