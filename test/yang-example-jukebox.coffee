should = require 'should'

describe "YANG Jukebox Example", ->
  model = undefined
  before ->
    model = (require '../example/jukebox').eval {
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
    jukebox = model.should.have.property('example-jukebox:jukebox').obj
    jukebox.should.have.property('playlist')
    jukebox.playlist.should.be.instanceof(Array).and.have.length(1)

  it 'should setup jukebox library', ->
    model['example-jukebox:jukebox'].library =
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
    model['example-jukebox:jukebox'].playlist['ellie playtime'].song = [
      index: 1
      id: 'old mcdonald had a farm'
    ]

  it 'should play the song', ->
    model.play 
      playlist: 'ellie playtime',
      'song-number': 1
    .then (res) -> should(res).equal('ok')
