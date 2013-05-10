
@getCharFromKeypress = (e) ->
  e = e || window.event
  charCode = e.charCode || e.keyCode
  char = String.fromCharCode(charCode)
  char

@setUserDirection = (dir) ->
  user = window.game.getPlayer(window.userID)
  user.direction = dir

@getCirclesFromExplosions = (explosions) ->
  duration = 200
  explosions.filter( (e) ->
    Date.now() - e.time <= duration
  ).map( (e) ->
    t = Date.now() - e.time
    {x: e.x, y: e.y, radius: 30 * t / duration}
  )

@getPointsFromPlayers = (players) ->
  points = players.slice(0)
  for i in [0...points.length]
    if points[i].dead
      points[i].color = "black"
    else if i == window.userID
      points[i].color = "#CF0060"
    else
      points[i].color = "#00A0C4"
  points

handleKeyDown = (e) ->
  keyToDirection = {A: 'L', D: 'R', W: 'U', S: 'D'}
  char = window.getCharFromKeypress(e)
  return unless char in ['A', 'W', 'S', 'D', ' ']

  if window.status == 'idle'
    joinGame() if char == ' '
  else if window.status == 'playing'
    if char == ' '
      window.game.playerAttack(window.userID)
      console.log "emitting attack!"
      window.room.emit('attack')
    else
      window.keyDown = char
      window.setUserDirection(keyToDirection[char])
      window.room.emit('setDirection', {dir: keyToDirection[char]})

  e.preventDefault(); 

handleKeyUp = (e) ->
  char = window.getCharFromKeypress(e)
  return unless char == window.keyDown
  window.keyDown = null
  window.setUserDirection('X')
  window.room.emit('setDirection', {dir: 'X'})
  e.preventDefault(); 

connect = ->
  if window.lobby
    window.lobby.removeAllListeners('connect')
    window.lobby.removeAllListeners('connect_failed')
    window.lobby.removeAllListeners('disconnect')
    window.lobby.removeAllListeners('clientid')
    window.lobby.disconnect()
    window.lobby = null

  window.status = 'connecting'
  $("#status").html("Connecting...")
  window.lobby = io.connect('http://localhost:3000', { reconnect: false })
  window.lobby.on 'connect_failed', ->
    console.log "Connection failed. Trying again in 5 seconds..."
    setTimeout(connect, 5000)

  window.lobby.on 'connect', ->
    console.log "Connected!"
    window.status = 'idle'
    $("#status").html("Connected, press SPACEBAR to join a game!")

  window.lobby.on 'clientid', (data) ->
    window.clientID = data.id

  window.lobby.on 'disconnect', ->
    window.status = 'disconnected'
    if window.room
      window.room.disconnect()
      window.room = null
      clearInterval(window.gameLoopRef) if window.gameLoopRef
      $("#status").html('Lost connection to the server, attempting to reconnect in 5 seconds...')
      setTimeout(connect, 5000)
  window.lobby.on 'disconnected'

joinGame = ->
  window.lobby.emit('join')
  window.status = 'waiting'
  $("#status").html("Waiting for another player...")
  
  window.lobby.on 'start-game', (data) ->
    console.log "Joined game #{data.gameID}"
    window.status = 'playing'
    $("#status").html("GO!")
    setTimeout( ->
      $("#status").html("")
    , 500)

    window.userID = data.playerID
    window.room = io.connect("http://localhost:3000/game/#{data.gameID}", { reconnect: false })
    window.room.on 'state', (state) ->
      window.game.setState state if window.status == 'playing'

    window.room.on 'gameover', (data) ->
      window.status = 'idle'
      window.room.disconnect()
      window.room = null
      setTimeout( ->
        clearInterval(window.gameLoopRef)
      , 1000)
      p.direction = 'X' for p in window.game.players
      if data.reason == 'disconnect'
        $("#status").html("Your opponent disconnected. Press SPACEBAR to find another game!")
      else 
        if data.result == 'draw'
          $("#status").html("It's a draw! Press SPACEBAR to find another game!")
        else
          if data.winner == window.clientID
            $("#status").html("You won! Press SPACEBAR to find another game!")
          else
            $("#status").html("You lost! Press SPACEBAR to find another game!")

    window.prev = Date.now()
    window.gameLoopRef = setInterval(gameLoop, 1000/60)

gameLoop = ->
  delta = (Date.now() - window.prev)/1000
  window.prev = Date.now()
  
  window.game.update(delta)
  window.renderer.render(window.getPointsFromPlayers(window.game.players), window.getCirclesFromExplosions(window.game.explosions))

$(document).ready ->
  window.game = new window.Game()
  window.renderer = new window.Renderer(document.getElementById("game").getContext("2d"))
  window.userID = 0
  window.keyDown = null
  document.onkeydown = handleKeyDown 
  document.onkeyup = handleKeyUp

  connect()
