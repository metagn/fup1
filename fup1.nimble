# Package

version       = "0.2.3"
author        = "hlaaftana"
description   = "googoo"
license       = "MIT"
srcDir        = "src"
bin           = @["fup1"]


# Dependencies

requires "nim >= 1.4.2"
requires "https://github.com/hlaaftana/schemes#head"
requires "https://github.com/hlaaftana/sdlutils#head"

task compileAll, "compiles for all platforms":
  exec "nim c -d:danger src/fup1"
  exec "nim c -d:danger -d:compile32bit src/fup1"
  exec "nim js -d:danger --outdir:. src/fup1"
