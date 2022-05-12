@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\bin\BuildTool.ps1' -Build"
timeout /t 5