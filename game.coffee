( (exports) -> 
  class Game
    dx = {R: 1, L: -1, U: 0, D: 0}
    dy = {R: 0, L: 0, U: -1, D: 1}
    speed = 80
    explosion_radius = 30
    width = 800
    height = 600
    player_size = 10
    attack_wait_time = 200

    distance = (a, b) -> return Math.sqrt(Math.pow((a.x - b.x), 2) + Math.pow((a.y - b.y), 2))

    constructor: (@players = [], @explosions = []) ->
      @lastAttack = new Array @players.length
      @lastAttack[i] = 0 for i in [0...@players.length]

    update: (delta) ->
      for p in @players
        if p.direction in ["R", "L", "U", "D"]  and not p.dead
          p.x += dx[p.direction] * delta * speed
          p.y += dy[p.direction] * delta * speed

          p.x -= dx[p.direction] * delta * speed if p.x - player_size/2 < 0 or p.x + player_size/2 > width
          p.y -= dy[p.direction] * delta * speed if p.y - player_size/2 < 0 or p.y + player_size/2 > height

    getPlayer: (id) -> @players[id]
    alivePlayers: -> @players.filter( (p) -> not p.dead )

    getState: -> {players: @players, explosions: @explosions, lastAttack: @lastAttack}
    setState: (state) ->
      @players = state.players
      @explosions = state.explosions
      @lastAttack = state.lastAttack

    playerAttack: (id) ->
      return if Date.now() - @lastAttack[id] <= attack_wait_time
      @lastAttack[id] = Date.now()
      player = @players[id]
      exp = {x: player.x, y: player.y, time: Date.now()}

      for i in [0...@players.length]
        continue if id == i
        p = @players[i]
        p.dead = true if distance(p, exp) <= explosion_radius

      @explosions.push exp

  exports.Game = Game
)(
  if typeof global == "undefined" then window
  else exports
)
