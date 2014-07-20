fs = require 'fs'

process.chdir 'server'

fs.stat 'ide.coffee', (err, stats)->
	if err then console.error err 
	else console.dir stats