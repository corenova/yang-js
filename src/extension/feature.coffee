Extension = require '../extension'
Yang      = require '../yang'

module.exports =
  new Extension 'feature',
    argument: 'name'
    scope:
      description:  '0..1'
      'if-feature': '0..n'
      reference:    '0..1'
      status:       '0..1'
      # TODO: augment scope with additional details
      # rpc:     '0..n'
      # feature: '0..n'

    resolve: ->
      if @status?.tag is 'unavailable'
        console.warn "feature #{@tag} is unavailable"

    compose: (data, opts={}) ->
      return if data?.constructor is Object
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data.prototype).length is 0

      # TODO: expand on data with additional details...
      (new Yang @tag, opts.key ? data.name).bind data
