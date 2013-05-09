class @Renderer
  size = 10

  # Public API
  constructor: (@ctx) ->

  clearScreen: -> @ctx.clearRect(0, 0, @ctx.canvas.width, @ctx.canvas.height)

  render: (points, circles) ->
    @clearScreen()

    for p in points
      @ctx.fillStyle = p.color
      @ctx.fillRect(p.x - (size/2), p.y - (size/2), size, size)

    @ctx.lineWidth = 2
    @ctx.strokeStyle = "FFBB00"
    for c in circles
      @ctx.beginPath()
      @ctx.arc(c.x, c.y, c.radius, 0, 2 * Math.PI, false)
      @ctx.stroke()

