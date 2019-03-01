# Grouping - special free-form object

debug = require('debug')('yang:grouping')
Container = require('./container')

class Grouping extends Container

  @property 'content',
    get: -> @state.value

  debug: -> debug @uri, arguments...

module.exports = Grouping
