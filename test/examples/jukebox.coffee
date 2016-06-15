# Example: jukebox module implementation

yang   = require '../..'
fs     = require 'fs'
schema = fs.readFileSync(__dirname+'/jukebox.yang','utf8')

module.exports = (yang schema) {
  jukebox:
    library: {}
    playlist: [
      {
        name: 'my favorite tunes',
        description: 'initial empty list'
      }
    ]
  play: (input, resolve, reject) ->
    playlist = @get "../jukebox/playlist[#{input.playlist}]"
    if playlist?
      song = playlist.__.get "song[#{input['song-number']}]"
      if song? then resolve "ok"
      else reject "selected song #{input['song-number']} not found in playlist"
    else reject "selected playlist '#{input.playlist}' not found"
}
