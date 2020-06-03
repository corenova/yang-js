# Example: jukebox module implementation
require('..')

module.exports = require('./jukebox.yang').bind {

  # bind behavior to config: false read-only elements
  '/jukebox/library/artist-count': get: (ctx) -> ctx.get('../artist')?.length ? 0
  '/jukebox/library/album-count':  get: (ctx) -> ctx.get('../artist/album')?.length ? 0
  '/jukebox/library/song-count':   get: (ctx) -> ctx.get('../artist/album/song')?.length ? 0
  
  '/play': (ctx, input) ->
    song = ctx.get (
      "/jukebox/playlist['#{input.playlist}']/" +
      "song['#{input['song-number']}']"
    )
    unless song?
      throw ctx.error "selected song #{input['song-number']} not found in library"
    else if song.id instanceof Error
      throw ctx.error song.id
    else
      return "ok"
}
