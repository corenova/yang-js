# Example: jukebox module implementation
require('..')

module.exports = require('./jukebox.yang').bind {

  # bind behavior to config: false read-only elements
  '/jukebox/library/artist-count': -> @get('../artist')?.length ? 0
  '/jukebox/library/album-count':  -> @get('../artist/album')?.length ? 0
  '/jukebox/library/song-count':   -> @get('../artist/album/song')?.length ? 0
  
  '/play': ->
    song = @get (
      "/jukebox/playlist[key('#{@input.playlist}')]/" +
      "song[key('#{@input['song-number']}')]"
    )
    unless song?
      @throw "selected song #{@input['song-number']} not found in library"
    else if song.id instanceof Error
      @throw song.id
    else
      @output = "ok"
}
