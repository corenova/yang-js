should = require 'should'

describe "YANG Jukebox Example", ->
  jbox = undefined
  before ->
    jbox = require('../example/jukebox').eval {
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
    jbox.get('/jukebox/playlist').should.be.instanceof(Array).and.have.length(1)

  it 'should setup jukebox library', ->
    jbox.get('/jukebox').library =
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
    jbox.get('/jukebox/playlist/ellie playtime').song = [
      index: 1
      id: 'old mcdonald had a farm'
    ]

  it 'should play the song', ->
    console.warn(jbox.get("/jukebox/playlist['ellie playtime']"));
    jbox.get("/jukebox/playlist['ellie playtime']/song").forEach (song) ->
      console.warn(song);
    jbox.in('play').do
      playlist: 'ellie playtime',
      'song-number': 1
    .then (res) -> should(res).equal('ok')
