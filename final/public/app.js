(function() {
  var connect, gameLoop, handleKeyDown, handleKeyUp, joinGame;

  this.getCharFromKeypress = function(e) {
    var char, charCode;
    e = e || window.event;
    charCode = e.charCode || e.keyCode;
    char = String.fromCharCode(charCode);
    return char;
  };

  this.setUserDirection = function(dir) {
    var user;
    user = window.game.getPlayer(window.userID);
    return user.direction = dir;
  };

  this.getCirclesFromExplosions = function(explosions) {
    var duration;
    duration = 200;
    return explosions.filter(function(e) {
      return Date.now() - e.time <= duration;
    }).map(function(e) {
      var t;
      t = Date.now() - e.time;
      return {
        x: e.x,
        y: e.y,
        radius: 30 * t / duration
      };
    });
  };

  this.getPointsFromPlayers = function(players) {
    var i, points, _ref;
    points = players.slice(0);
    for (i = 0, _ref = points.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
      if (points[i].dead) {
        points[i].color = "black";
      } else if (i === window.userID) {
        points[i].color = "#99000A";
      } else {
        points[i].color = "#258701";
      }
    }
    return points;
  };

  handleKeyDown = function(e) {
    var char, keyToDirection;
    keyToDirection = {
      A: 'L',
      D: 'R',
      W: 'U',
      S: 'D'
    };
    char = window.getCharFromKeypress(e);
    if (char !== 'A' && char !== 'W' && char !== 'S' && char !== 'D' && char !== ' ') {
      return;
    }
    if (window.status === 'idle') {
      if (char === ' ') joinGame();
    } else if (window.status === 'playing') {
      if (char === ' ') {
        window.game.playerAttack(window.userID);
        console.log("emitting attack!");
        window.room.emit('attack');
      } else {
        window.keyDown = char;
        window.setUserDirection(keyToDirection[char]);
        window.room.emit('setDirection', {
          dir: keyToDirection[char]
        });
      }
    }
    return e.preventDefault();
  };

  handleKeyUp = function(e) {
    var char;
    char = window.getCharFromKeypress(e);
    if (char !== window.keyDown) return;
    window.keyDown = null;
    window.setUserDirection('X');
    window.room.emit('setDirection', {
      dir: 'X'
    });
    return e.preventDefault();
  };

  connect = function() {
    if (window.lobby) {
      window.lobby.removeAllListeners('connect');
      window.lobby.removeAllListeners('connect_failed');
      window.lobby.removeAllListeners('disconnect');
      window.lobby.removeAllListeners('clientid');
      window.lobby.disconnect();
      window.lobby = null;
    }
    window.status = 'connecting';
    $("#status").html("Connecting...");
    window.lobby = io.connect('/', {
      reconnect: false
    });
    window.lobby.on('connect_failed', function() {
      console.log("Connection failed. Trying again in 5 seconds...");
      return setTimeout(connect, 5000);
    });
    window.lobby.on('connect', function() {
      window.status = 'idle';
      return $("#status").html("Connected, press SPACEBAR to join a game!");
    });
    window.lobby.on('clientid', function(data) {
      return window.clientID = data.id;
    });
    return window.lobby.on('disconnect', function() {
      window.status = 'disconnected';
      if (window.room) {
        window.room.disconnect();
        window.room = null;
      }
      if (window.gameLoopRef) clearInterval(window.gameLoopRef);
      $("#status").html('Lost connection to the server, attempting to reconnect in 5 seconds...');
      return setTimeout(connect, 5000);
    });
  };

  joinGame = function() {
    window.lobby.emit('join');
    window.status = 'waiting';
    $("#status").html("Waiting for another player...");
    return window.lobby.on('start-game', function(data) {
      console.log("Joined game " + data.gameID);
      window.status = 'playing';
      $("#status").html("GO!");
      setTimeout(function() {
        return $("#status").html("");
      }, 500);
      window.userID = data.playerID;
      window.room = io.connect("/game/" + data.gameID, {
        reconnect: false
      });
      window.room.on('state', function(state) {
        if (window.status === 'playing') return window.game.setState(state);
      });
      window.room.on('gameover', function(data) {
        var p, _i, _len, _ref;
        window.status = 'idle';
        window.room.disconnect();
        window.room = null;
        setTimeout(function() {
          return clearInterval(window.gameLoopRef);
        }, 1000);
        _ref = window.game.players;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          p = _ref[_i];
          p.direction = 'X';
        }
        if (data.reason === 'disconnect') {
          return $("#status").html("Your opponent disconnected. Press SPACEBAR to find another game!");
        } else {
          if (data.result === 'draw') {
            return $("#status").html("It's a draw! Press SPACEBAR to find another game!");
          } else {
            if (data.winner === window.clientID) {
              return $("#status").html("You won! Press SPACEBAR to find another game!");
            } else {
              return $("#status").html("You lost! Press SPACEBAR to find another game!");
            }
          }
        }
      });
      window.prev = Date.now();
      return window.gameLoopRef = setInterval(gameLoop, 1000 / 60);
    });
  };

  gameLoop = function() {
    var delta;
    delta = (Date.now() - window.prev) / 1000;
    window.prev = Date.now();
    window.game.update(delta);
    return window.renderer.render(window.getPointsFromPlayers(window.game.players), window.getCirclesFromExplosions(window.game.explosions));
  };

  $(document).ready(function() {
    window.game = new window.Game();
    window.renderer = new window.Renderer(document.getElementById("game").getContext("2d"));
    window.userID = 0;
    window.keyDown = null;
    document.onkeydown = handleKeyDown;
    document.onkeyup = handleKeyUp;
    return connect();
  });

}).call(this);
