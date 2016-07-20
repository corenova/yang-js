# Example: jukebox module implementation

yang   = require '..'
fs     = require 'fs'
schema = fs.readFileSync(__dirname+'/jukebox.yang','utf8')

module.exports = yang.parse(schema).bind {

  # bind behavior to config: false read-only elements
  '/jukebox/library/artist-count': -> @get('../artist')?.length ? 0
  '/jukebox/library/album-count':  -> @get('../artist/album')?.length ? 0
  '/jukebox/library/song-count':   -> @get('../artist/album/song')?.length ? 0
  
  '[rpc:play]': (input, resolve, reject) ->
    song = @get (
      "/jukebox/playlist[key() = '#{input.playlist}']/" +
      "song[key() = '#{input['song-number']}']"
    )
    if song? and song.id not instanceof Error
      resolve "ok"
    else
      reject "selected song #{input['song-number']} not found in library"
}
