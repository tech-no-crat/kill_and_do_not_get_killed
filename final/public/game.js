(function() {

  (function(exports) {
    var Game;
    Game = (function() {
      var attack_wait_time, distance, dx, dy, explosion_radius, height, player_size, speed, width;

      dx = {
        R: 1,
        L: -1,
        U: 0,
        D: 0
      };

      dy = {
        R: 0,
        L: 0,
        U: -1,
        D: 1
      };

      speed = 80;

      explosion_radius = 30;

      width = 800;

      height = 600;

      player_size = 10;

      attack_wait_time = 200;

      distance = function(a, b) {
        return Math.sqrt(Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2));
      };

      function Game(players, explosions) {
        var i, _ref;
        this.players = players != null ? players : [];
        this.explosions = explosions != null ? explosions : [];
        this.lastAttack = new Array(this.players.length);
        for (i = 0, _ref = this.players.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          this.lastAttack[i] = 0;
        }
      }

      Game.prototype.update = function(delta) {
        var p, _i, _len, _ref, _ref2, _results;
        _ref = this.players;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          p = _ref[_i];
          if (((_ref2 = p.direction) === "R" || _ref2 === "L" || _ref2 === "U" || _ref2 === "D") && !p.dead) {
            p.x += dx[p.direction] * delta * speed;
            p.y += dy[p.direction] * delta * speed;
            if (p.x - player_size / 2 < 0 || p.x + player_size / 2 > width) {
              p.x -= dx[p.direction] * delta * speed;
            }
            if (p.y - player_size / 2 < 0 || p.y + player_size / 2 > height) {
              _results.push(p.y -= dy[p.direction] * delta * speed);
            } else {
              _results.push(void 0);
            }
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      };

      Game.prototype.getPlayer = function(id) {
        return this.players[id];
      };

      Game.prototype.alivePlayers = function() {
        return this.players.filter(function(p) {
          return !p.dead;
        });
      };

      Game.prototype.getState = function() {
        return {
          players: this.players,
          explosions: this.explosions,
          lastAttack: this.lastAttack
        };
      };

      Game.prototype.setState = function(state) {
        this.players = state.players;
        this.explosions = state.explosions;
        return this.lastAttack = state.lastAttack;
      };

      Game.prototype.playerAttack = function(id) {
        var exp, i, p, player, _ref;
        if (Date.now() - this.lastAttack[id] <= attack_wait_time) return;
        this.lastAttack[id] = Date.now();
        player = this.players[id];
        exp = {
          x: player.x,
          y: player.y,
          time: Date.now()
        };
        for (i = 0, _ref = this.players.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          if (id === i) continue;
          p = this.players[i];
          if (distance(p, exp) <= explosion_radius) p.dead = true;
        }
        return this.explosions.push(exp);
      };

      Game.prototype.willStayInBounds = function(id, dir, time) {
        var dist, x, y;
        dist = time * speed;
        x = this.players[id].x;
        y = this.players[id].y;
        if (dir === 'R') {
          return (x + dist + player_size / 2) <= width;
        } else if (dir === 'L') {
          return (x - dist - player_size / 2) >= 0;
        } else if (dir === 'D') {
          return (y + dist + player_size / 2) <= height;
        } else if (dir === 'U') {
          return (y - dist - player_size / 2) >= 0;
        } else {
          return true;
        }
      };

      return Game;

    })();
    return exports.Game = Game;
  })(typeof global === "undefined" ? window : exports);

}).call(this);
