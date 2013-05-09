#!/bin/sh

haml index.haml > final/index.html
sass style.scss final/public/style.css

coffee -c server.coffee
coffee -c app.coffee
coffee -c game.coffee
coffee -c renderer.coffee

mv server.js final/server.js
mv app.js final/public/app.js
mv game.js final/public/game.js
mv renderer.js final/public/renderer.js
