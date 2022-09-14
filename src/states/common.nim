import ".."/[backend, bridge, data]
export backend, bridge, data

when canvasBackend:
  template drawColor*(r, g, b, a: byte) =
    global.context.fillStyle = cstring(color(r, g, b, a))
    global.context.strokeStyle = cstring(color(r, g, b, a))

  template drawColor*(r, g, b: byte) =
    global.context.fillStyle = cstring(color(r, g, b))
    global.context.strokeStyle = cstring(color(r, g, b))

  template drawColor*(col: Color) =
    global.context.fillStyle = cstring(col)
    global.context.strokeStyle = cstring(col)
  
  template setVolume*(vol: cint) =
    global.musicVolume = vol
    global.currentMusic.setVolume(global.musicVolume.int)

  template draw*(t: TexturePtr, x, y, w, h: cint) =
    global.context.drawImage(t, x, y, w, h)

  template draw*(t: TexturePtr, x, y: cint) =
    global.context.drawImage(t, x, y)

  template fillRect*(x, y, w, h: cint) =
    global.context.fillRect(x, y, w, h)
  
  template drawRect*(x, y, w, h: cint) =
    global.context.beginPath()
    global.context.rect(x, y, w, h)
    global.context.stroke()
elif sdlBackend:
  template drawColor*(r, g, b: byte, a = 255u8) =
    global.renderer.setDrawColor(r, g, b, a)

  template drawColor*(col: Color) =
    global.renderer.setDrawColor(col)

  template loadTexture*(file: cstring): TexturePtr =
    global.renderer.loadTexture(file)
  
  template setVolume*(vol: cint) =
    global.musicVolume = vol
    discard volumeMusic(global.musicVolume)

  template draw*(t: TexturePtr, x, y, w, h: cint) =
    global.renderer.draw(t, rect(x, y, w, h))

  template draw*(t: TexturePtr, x, y: cint) =
    global.renderer.draw(t, x, y)

  template fillRect*(x, y, w, h: cint) =
    var rect = rect(x, y, w, h)
    global.renderer.fillRect(addr rect)

  template drawRect*(x, y, w, h: cint) =
    var rect = rect(x, y, w, h)
    global.renderer.drawRect(addr rect)

proc preRender*(global: Global) =
  drawColor(0, 0, 0)
  when canvasBackend:
    global.context.clearRect(0, 0, global.canvas.width, global.canvas.height)
  elif sdlBackend:
    global.renderer.clear()

proc postRender*(global: Global) =
  when sdlBackend:
    global.renderer.present()
