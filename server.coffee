shared = require(__dirname + '/public/game.js')
express = require('express')
app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server)
usage = require('usage');

Game = shared.Game

info = {startTime: Date.now(), usersOnline: 0, waiting: 0, gamesPlaying: 0, gamesStarted: 0, gamesFinished: 0, cpu: 0, memory: 0}

app.use express.static(__dirname + '/public')
app.set('log level', 1)

app.get '/', (req, res) ->
  res.sendfile(__dirname + '/index.html')

app.get '/info', (req, res) ->
  res.send JSON.stringify(info)

io.set('log level', 1)

clientGameID = {}
waiting = null
io.sockets.on 'connection', (client) ->
  info.usersOnline += 1
  address = client.handshake.address
  console.log "Client #{client.id} connected from #{address.address}:#{address.port}"

  client.emit('clientid', {id: client.id})
  client.on 'disconnect', ->
    info.usersOnline -= 1
    gameID = clientGameID[this.id]
    console.log "Client #{this.id} disconnected"
    waiting = null if waiting and waiting.id == this.id
    endGame(gameID, null, true) if gameID
  
  client.on 'join', ->
    unless waiting
      waiting = client
      info.waiting = 1
    else
      return if waiting.id == client.id
      setupGame(client, waiting)
      waiting = null
      info.waiting = 0
  

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
        info.gamesPlaying += 1
        info.gamesStarted += 1
        game.last_update = Date.now()
        for i in [0..9]
          initAI(gameID, i) unless i == game.playerID[game.player_ids[0]] or i == game.playerID[game.player_ids[1]]
        game.loopRef = setInterval( ->
          gameLoop(gameID)
        , 1000/60)

initAI = (gameID, ind) ->
  game = games[gameID]
  return unless game
  
  if random(1, 2) == 1
    moveBot(gameID, ind)
  else
    sleepBot(gameID, ind) 

sleepBot = (gameID, ind) ->
  game = games[gameID]
  return unless game

  game.state.players[ind].direction = 'X'
  setTimeout( ->
    moveBot(gameID, ind)
  , random(1000, 8000))

moveBot = (gameID, ind) ->
  game = games[gameID]
  return unless game

  loop
    dir = randomDirection()
    time = random(1000, 8000)
    break if game.state.willStayInBounds(ind, dir, time/1000)

  game.state.players[ind].direction = dir
  setTimeout( ->
    sleepBot(gameID, ind)
  , time)

playerAttack = (player) ->
  game = games[player.gameID]
  return unless game
  game.state.playerAttack game.playerID[player.id]
  gameLoop(player.gameID)

playerSetDirection = (player, direction) ->
  game = games[player.gameID]
  return unless game
  game.state.players[game.playerID[player.id]].direction = direction
  gameLoop(player.gameID)

gameLoop = (gameID) ->
  game = games[gameID]
  delta = (Date.now() - game.last_update)/1000
  game.last_update = Date.now()

  game.state.update(delta)
  io.of("/game/#{gameID}").emit('state', game.state.getState())

  player1 = game.state.players[game.playerID[game.player_ids[0]]]
  player2 = game.state.players[game.playerID[game.player_ids[1]]]
  if player1.dead or player2.dead
    if not player2.dead
      endGame(gameID, game.player_ids[1])
    else if not player1.dead
      endGame(gameID, game.player_ids[0])
    else
      endGame(gameID)

endGame = (gameID, winner, disconnection) ->
  game = games[gameID]
  return unless game
  clearInterval(game.loopRef)
  games[gameID] = undefined
  info.gamesPlaying -= 1

  if disconnection
    data = {reason: "disconnect", result: "draw"}
  else if winner
    data = {reason: "ok", result: "winner", winner: winner}
  else
    data = {reason: "ok", result: "draw"}

  info.gamesFinished += 1 if data.reason == "ok"
  io.of("/game/#{gameID}").emit('gameover', data)

generateGameID = -> Math.random().toString(36).substring(7)
generateRandomPlayers = ->
  a = []
  a.push {x: random(10, 790), y: random(10, 590), direction: 'X'} for i in [0...10]
  return a

random = (min, max) -> Math.floor(Math.random() * (max - min + 1)) + min
randomDirection = -> {1: 'U', 2: 'D', 3: 'R', 4: 'L'}[random(1, 4)]

randomIndicesForPlayers = (x, y, min, max) ->
  h = {}
  h[x.id] = h[y.id] = random(min, max)
  return h if min == max or y.id == x.id
  h[y.id] = random(min, max) until h[y.id] != h[x.id]
  console.log "ids: #{h[x.id]}, #{h[y.id]}"

  return h

setInterval( ->
  usage.lookup process.pid, {keepHistory: true}, (err, res) ->
    if res
      info.cpu = res.cpu
      info.meomory = res.memory
, 5000)

server.listen(3000)
