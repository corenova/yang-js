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
    song = @get (
      "../jukebox/playlist[key() = '#{input.playlist}']/" +
      "song[key() = '#{input['song-number']}']"
    )
    if song? and song.id not instanceof Error
      resolve "ok"
    else
      reject "selected song #{input['song-number']} not found in library"
}
