# Package

version       = "0.3.0"
author        = "metagn"
description   = "googoo"
license       = "MIT"
srcDir        = "src"
bin           = @["fup1"]


# Dependencies

requires "nim >= 1.4.2"
requires "sdl2"
requires "https://github.com/metagn/sdlutils#head"
requires "jscanvas"

task browser, "compiles for browser":
  exec "nim js -d:danger --outdir:. src/fup1"

task compileAll, "compiles for all platforms":
  exec "nim c -d:danger src/fup1"
  exec "nim c -d:danger -d:compile32bit src/fup1"
  exec "nim js -d:danger --outdir:. src/fup1"
