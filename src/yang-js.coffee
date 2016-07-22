fs   = require 'fs'
path = require 'path'
Yang = require './yang'

schema = (fs.readFileSync (path.resolve __dirname, '../yang-js.yang'), 'utf-8')
module.exports =
  new Yang schema, require('./yang-language')
  .bind 
    parse: (schema) -> (yang schema)
    resolve: ->
