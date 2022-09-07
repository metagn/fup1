when defined(js):
  import backend/canvas
  export canvas

  const canvasBackend* = true
  const sdlBackend* = false
else:
  import backend/sdl
  export sdl

  const canvasBackend* = false
  const sdlBackend* = true
