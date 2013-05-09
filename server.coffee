express = require('express')
app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server)

app.use(express.static(__dirname + '/public'))

app.get '/', (req, res) ->
  res.sendfile(__dirname + '/index.html')

server.listen(3000)
