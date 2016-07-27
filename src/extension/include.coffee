Extension = require '../extension'

module.exports =
  new Extension 'include',
    argument: module
    scope:
      'revision-date': '0..1'
    resolve: ->
      m = @lookup 'submodule', @tag
      unless m?
        throw @error "unable to resolve '#{@tag}' submodule"
      unless (@parent.tag is m['belongs-to'].tag)
        throw @error "requested submodule '#{@tag}' does not belongs-to '#{@parent.tag}'"
      @parent.extends m.elements...

