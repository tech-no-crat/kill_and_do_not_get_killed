(function() {
  var Game, app, clientGameID, endGame, express, gameLoop, games, generateGameID, generateRandomPlayers, info, initAI, io, moveBot, playerAttack, playerSetDirection, random, randomDirection, randomIndicesForPlayers, server, setupGame, shared, sleepBot, usage, waiting,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  shared = require(__dirname + '/public/game.js');

  express = require('express');

  app = express();

  server = require('http').createServer(app);

  io = require('socket.io').listen(server);

  usage = require('usage');

  Game = shared.Game;

  info = {
    startTime: Date.now(),
    usersOnline: 0,
    waiting: 0,
    gamesPlaying: 0,
    gamesStarted: 0,
    gamesFinished: 0,
    cpu: 0,
    memory: 0
  };

  app.use(express.static(__dirname + '/public'));

  app.set('log level', 1);

  app.get('/', function(req, res) {
    return res.sendfile(__dirname + '/index.html');
  });

  app.get('/info', function(req, res) {
    return res.send(JSON.stringify(info));
  });

  io.set('log level', 1);

  clientGameID = {};

  waiting = null;

  io.sockets.on('connection', function(client) {
    var address;
    info.usersOnline += 1;
    address = client.handshake.address;
    console.log("Client " + client.id + " connected from " + address.address + ":" + address.port);
    client.emit('clientid', {
      id: client.id
    });
    client.on('disconnect', function() {
      var gameID;
      info.usersOnline -= 1;
      gameID = clientGameID[this.id];
      console.log("Client " + this.id + " disconnected");
      if (waiting && waiting.id === this.id) waiting = null;
      if (gameID) return endGame(gameID, null, true);
    });
    return client.on('join', function() {
      if (!waiting) {
        waiting = client;
        return info.waiting = 1;
      } else {
        if (waiting.id === client.id) return;
        setupGame(client, waiting);
        waiting = null;
        return info.waiting = 0;
      }
    });
  });

  games = {};

  setupGame = function(x, y) {
    var game, gameID;
    gameID = generateGameID();
    games[gameID] = {
      id: gameID,
      playerCount: 0,
      state: new Game(generateRandomPlayers()),
      player_ids: [x.id, y.id],
      status: "waiting",
      playerID: randomIndicesForPlayers(x, y, 0, 9),
      loopRef: null
    };
    game = games[gameID];
    x.emit('start-game', {
      gameID: gameID,
      playerID: game.playerID[x.id]
    });
    y.emit('start-game', {
      gameID: gameID,
      playerID: game.playerID[y.id]
    });
    console.log("Starting game " + gameID + " between players " + x.id + " and " + y.id);
    return io.of("/game/" + gameID).on('connection', function(client) {
      var i, _ref;
      if (_ref = client.id, __indexOf.call(game.player_ids, _ref) >= 0) {
        console.log("Player " + client.id + " joined game " + gameID);
        game.playerCount += 1;
        client.gameID = gameID;
        clientGameID[client.id] = gameID;
        client.on('attack', function() {
          return playerAttack(this);
        });
        client.on('setDirection', function(data) {
          return playerSetDirection(this, data.dir);
        });
        if (game.playerCount === 2) {
          console.log("Game " + gameID + " starts");
          info.gamesPlaying += 1;
          info.gamesStarted += 1;
          game.last_update = Date.now();
          for (i = 0; i <= 9; i++) {
            if (!(i === game.playerID[game.player_ids[0]] || i === game.playerID[game.player_ids[1]])) {
              initAI(gameID, i);
            }
          }
          return game.loopRef = setInterval(function() {
            return gameLoop(gameID);
          }, 1000 / 60);
        }
      }
    });
  };

  initAI = function(gameID, ind) {
    var game;
    game = games[gameID];
    if (!game) return;
    if (random(1, 2) === 1) {
      return moveBot(gameID, ind);
    } else {
      return sleepBot(gameID, ind);
    }
  };

  sleepBot = function(gameID, ind) {
    var game;
    game = games[gameID];
    if (!game) return;
    game.state.players[ind].direction = 'X';
    return setTimeout(function() {
      return moveBot(gameID, ind);
    }, random(1000, 8000));
  };

  moveBot = function(gameID, ind) {
    var dir, game, time;
    game = games[gameID];
    if (!game) return;
    while (true) {
      dir = randomDirection();
      time = random(1000, 8000);
      if (game.state.willStayInBounds(ind, dir, time / 1000)) break;
    }
    game.state.players[ind].direction = dir;
    return setTimeout(function() {
      return sleepBot(gameID, ind);
    }, time);
  };

  playerAttack = function(player) {
    var game;
    game = games[player.gameID];
    if (!game) return;
    game.state.playerAttack(game.playerID[player.id]);
    return gameLoop(player.gameID);
  };

  playerSetDirection = function(player, direction) {
    var game;
    game = games[player.gameID];
    if (!game) return;
    game.state.players[game.playerID[player.id]].direction = direction;
    return gameLoop(player.gameID);
  };

  gameLoop = function(gameID) {
    var delta, game, player1, player2;
    game = games[gameID];
    delta = (Date.now() - game.last_update) / 1000;
    game.last_update = Date.now();
    game.state.update(delta);
    io.of("/game/" + gameID).emit('state', game.state.getState());
    player1 = game.state.players[game.playerID[game.player_ids[0]]];
    player2 = game.state.players[game.playerID[game.player_ids[1]]];
    if (player1.dead || player2.dead) {
      if (!player2.dead) {
        return endGame(gameID, game.player_ids[1]);
      } else if (!player1.dead) {
        return endGame(gameID, game.player_ids[0]);
      } else {
        return endGame(gameID);
      }
    }
  };

  endGame = function(gameID, winner, disconnection) {
    var data, game;
    game = games[gameID];
    if (!game) return;
    clearInterval(game.loopRef);
    games[gameID] = void 0;
    info.gamesPlaying -= 1;
    if (disconnection) {
      data = {
        reason: "disconnect",
        result: "draw"
      };
    } else if (winner) {
      data = {
        reason: "ok",
        result: "winner",
        winner: winner
      };
    } else {
      data = {
        reason: "ok",
        result: "draw"
      };
    }
    if (data.reason === "ok") info.gamesFinished += 1;
    return io.of("/game/" + gameID).emit('gameover', data);
  };

  generateGameID = function() {
    return Math.random().toString(36).substring(7);
  };

  generateRandomPlayers = function() {
    var a, i;
    a = [];
    for (i = 0; i < 10; i++) {
      a.push({
        x: random(10, 790),
        y: random(10, 590),
        direction: 'X'
      });
    }
    return a;
  };

  random = function(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  };

  randomDirection = function() {
    return {
      1: 'U',
      2: 'D',
      3: 'R',
      4: 'L'
    }[random(1, 4)];
  };

  randomIndicesForPlayers = function(x, y, min, max) {
    var h;
    h = {};
    h[x.id] = h[y.id] = random(min, max);
    if (min === max || y.id === x.id) return h;
    while (h[y.id] === h[x.id]) {
      h[y.id] = random(min, max);
    }
    console.log("ids: " + h[x.id] + ", " + h[y.id]);
    return h;
  };

  setInterval(function() {
    return usage.lookup(process.pid, {
      keepHistory: true
    }, function(err, res) {
      if (res) {
        info.cpu = res.cpu;
        return info.meomory = res.memory;
      }
    });
  }, 5000);

  server.listen(3000);

}).call(this);
