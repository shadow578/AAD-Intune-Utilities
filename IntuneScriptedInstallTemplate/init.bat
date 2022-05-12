@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\bin\BuildTool.ps1' -Init"
timeout /t 5