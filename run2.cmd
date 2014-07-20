@echo off
cls
call coffee --nodejs --harmony_generators server\server.coffee %1
