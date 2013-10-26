(function() {

  this.Renderer = (function() {
    var size;

    size = 10;

    function Renderer(ctx) {
      this.ctx = ctx;
    }

    Renderer.prototype.clearScreen = function() {
      return this.ctx.clearRect(0, 0, this.ctx.canvas.width, this.ctx.canvas.height);
    };

    Renderer.prototype.render = function(points, circles) {
      var c, p, _i, _j, _len, _len2, _results;
      this.clearScreen();
      for (_i = 0, _len = points.length; _i < _len; _i++) {
        p = points[_i];
        this.ctx.fillStyle = p.color;
        this.ctx.fillRect(p.x - (size / 2), p.y - (size / 2), size, size);
      }
      this.ctx.lineWidth = 2;
      this.ctx.strokeStyle = "#FF0000";
      _results = [];
      for (_j = 0, _len2 = circles.length; _j < _len2; _j++) {
        c = circles[_j];
        this.ctx.beginPath();
        this.ctx.arc(c.x, c.y, c.radius, 0, 2 * Math.PI, false);
        _results.push(this.ctx.stroke());
      }
      return _results;
    };

    return Renderer;

  })();

}).call(this);
