shared = require(__dirname + '/public/game.js')
express = require('express')
app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server)

Game = shared.Game

app.use express.static(__dirname + '/public')
app.set('log level', 1)

app.get '/', (req, res) ->
  res.sendfile(__dirname + '/index.html')

io.set('log level', 1)

clientGameID = {}
waiting = null
io.sockets.on 'connection', (client) ->
  address = client.handshake.address
  console.log "Client #{client.id} connected from #{address.address}:#{address.port}"

  client.on 'disconnect', ->
    gameID = clientGameID[this.id]
    console.log "Client #{this.id} disconnected"
    if gameID
      game = games[gameID]
      console.log "Ending game #{game.id}"
      io.of("/game/#{gameID}").emit('gameover', {reason: "disconnect", result: "draw"})
  
  client.on 'join', ->
    unless waiting
      waiting = client
    else
      return if waiting.id == client.id
      setupGame(client, waiting)
  

games = {}
setupGame = (x, y) ->
  gameID = generateGameID()
  games[gameID] = {id: gameID, playerCount: 0, state: new Game(generateRandomPlayers()), player_ids: [x.id, y.id], status: "waiting", playerID: randomIndicesForPlayers(x, y, 0, 9), loopRef: null}
  game = games[gameID]

  x.emit('start-game', {gameID: gameID, playerID: game.playerID[x.id]})
  y.emit('start-game', {gameID: gameID, playerID: game.playerID[y.id]})

  console.log "Starting game #{gameID} between players #{x.id} and #{y.id}"

  io.of("/game/#{gameID}").on 'connection', (client) ->

    if client.id in game.player_ids
      #TODO: Find a way to ensure that the same player hasn't connected twice
      console.log "Player #{client.id} joined game #{gameID}"
      game.playerCount += 1
      client.gameID = gameID
      clientGameID[client.id] = gameID
      
      client.on 'attack', -> playerAttack(this)
      client.on 'setDirection', (data) -> playerSetDirection(this, data.dir)
      

      if game.playerCount == 2
        # Start the game (setup the main game loop)
        console.log "Game #{gameID} starts"
        game.last_update = Date.now()
        game.loopRef = setInterval( ->
          gameLoop(gameID)
        , 1000/60)

playerAttack = (player) ->
  game = games[player.gameID]
  game.state.playerAttack game.playerID[player.id]

playerSetDirection = (player, direction) ->
  game = games[player.gameID]
  game.state.players[game.playerID[player.id]].direction = direction

gameLoop = (gameID) ->
  game = games[gameID]
  delta = (Date.now() - game.last_update)/1000
  game.last_update = Date.now()

  game.state.update(delta)
  io.of("/game/#{gameID}").emit('state', game.state.getState())

  player1 = game.state.players[playerID[player_ids[0]]]
  player2 = game.state.players[playerID[player_ids[1]]]
  if player1.dead or player2.dead
    if not player2.dead
      endGame(gameID, player_ids[0])
    else if not player1.dead
      endGame(gameID, player_ids[1])
    else
      endGame(gameID)

endGame = (gameID, winner) ->
  game = games[gameID]
  clearInterval(game.loopRef)
  games[gameID] = undefined

  if winner
    io.of("/game/#{gameID}").emit('gameover', {reason: "ok", result: "winner", winner: winner})
  else
    io.of("/game/#{gameID}").emit('gameover', {reason: "ok", result: "draw"})

generateGameID = -> Math.random().toString(36).substring(7)
generateRandomPlayers = ->
  a = []
  a.push {x: random(10, 790), y: random(10, 590), direction: randomDirection()} for i in [0...10]
  return a

random = (min, max) -> Math.floor(Math.random() * (max - min + 1)) + min
randomDirection = (num) -> {1: 'U', 2: 'D', 3: 'R', 4: 'L'}[random(1, 4)]

randomIndicesForPlayers = (x, y, min, max) ->
  h = {}
  h[x.id] = h[y.id] = random(min, max)
  return h if min == max or y.id == x.id
  h[y.id] = random(min, max) until h[y.id] != h[x.id]
  console.log "ids: #{h[x.id]}, #{h[y.id]}"

  return h

server.listen(3000)
