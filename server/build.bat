@echo off
echo building server

@echo on
call coffee --compile --bare .project.coffee
call coffee --compile --bare ..\config.coffee

@echo off
del .project.coffee.js
rename .project.js .project.coffee.js

cd ..
del config.coffee.js
rename config.js config.coffee.js

