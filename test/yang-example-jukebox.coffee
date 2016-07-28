should = require 'should'

describe "YANG Jukebox Example", ->
  juke = undefined
  before ->
    juke = (require '../examples/jukebox').eval {
      'example-jukebox:jukebox':
        library: {}
        playlist: [
          {
            name: 'ellie playtime',
            description: 'tunes for toddler play'
          }
        ]
    }

  it 'should contain initial playlist', ->
    jukebox = juke.should.have.property('example-jukebox:jukebox').obj
    jukebox.should.have.property('playlist')
    jukebox.playlist.should.be.instanceof(Array).and.have.length(1)

  it 'should setup jukebox library', ->
    juke['example-jukebox:jukebox'].library =
      artist: [
        name: 'Super Simple Songs'
        album: [
          name: 'Animals Vol. 1'
          year: '2015'
          song: [
            name: 'old mcdonald had a farm'
            location: '/hard/wired/in/my/head.mpg'
          ]
        ]
      ]

  it 'should enable adding a song to the playlist', ->
    juke['example-jukebox:jukebox'].playlist['ellie playtime'].song = [
      index: 1
      id: 'old mcdonald had a farm'
    ]

  it 'should play the song', ->
    juke.play 
      playlist: 'ellie playtime',
      'song-number': 1
    .then (res) -> should(res).equal('ok')
