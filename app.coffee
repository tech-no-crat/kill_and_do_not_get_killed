
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
    if i == window.userID
      points[i].color = "#CF0060"
    else
      points[i].color = "#00A0C4"
  points

$(document).ready ->

  points = [ {x: 5, y: 120} ]
  window.game = new window.Game([{x: 200, y:150, direction: 'X'}, {x: 280, y: 60, direction: 'D'}])
  window.renderer = new window.Renderer(document.getElementById("game").getContext("2d"))
  window.userID = 0

  keyDown = null
  document.onkeydown = (e) ->
    keyToDirection = {A: 'L', D: 'R', W: 'U', S: 'D'}
    char = window.getCharFromKeypress(e)
    return unless char in ['A', 'W', 'S', 'D', ' ']
    if char == ' '
      window.game.playerAttack(window.userID)
    else
      keyDown = char
      window.setUserDirection(keyToDirection[char])
    e.preventDefault(); 

  document.onkeyup = (e) ->
    char = window.getCharFromKeypress(e)
    return unless char == keyDown
    keyDown = null
    window.setUserDirection('X')
    e.preventDefault(); 
    

  prev = Date.now()
  setInterval( ->
    delta = (Date.now() - prev)/1000
    prev = Date.now()
    
    window.game.update(delta)
    window.renderer.render(window.getPointsFromPlayers(window.game.alivePlayers()), window.getCirclesFromExplosions(window.game.explosions))
  , 1000/60)
  
