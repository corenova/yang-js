should = require 'should'

describe "YANG Jukebox Example", ->
  juke = undefined
  before -> juke = require './examples/jukebox'

  it 'should contain initial playlist', ->
    juke.should.have.property('jukebox')
    juke.jukebox.should.have.property('playlist')
    juke.jukebox.playlist.should.be.instanceof(Array).and.have.length(1)

  it 'should setup jukebox library', ->
    juke.jukebox.library = {}

  it 'should enable adding a song to the playlist', ->
    juke.jukebox.playlist['my favorite tunes'].song = [
      index: 1
      id: 'my favorite song'
    ]

  it 'should play the song', ->
    juke.play 
      playlist: 'my favorite tunes',
      'song-number': 1
    .then (res) -> should(res).equal('ok')
