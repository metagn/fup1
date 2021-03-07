import schemes

when defined(js):
  import dom, jscanvas, jsgameutils
else:
  import sdlutils, sdl2, sdl2/[image, mixer]

import bridge

initScheme Game, {scfNoneState, scfVar, scfDeepRef}

proc init(state: Game) {.behavior, init.}
proc finish(state: Game) {.behavior.}

inject:
  template switch(state: Game, k: GameKind) {.dirty.} =
    finish(state)
    state = GameObj(kind: k)
    init(state)

const
  ReferenceWidth = 960
  ReferenceHeight = 540
  ReferenceFps = 120
  VariableFps = defined(js)

when defined(js):
  let canvas = CanvasElement getElementById("fup1")
  let context = canvas.getContext2d()
else:
  sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)
    .unwrap("couldn't initialize SDL")
  setHint("SDL_RENDER_SCALE_QUALITY", "2")
    .unwrap("couldn't set SDL render scale quality")

  let window = createWindow(
    "The Tetry Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
    ReferenceWidth, ReferenceHeight, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_OPENGL)
    .unwrap("couldn't create window")
  let renderer = window.createRenderer(-1,
    Renderer_Accelerated or Renderer_PresentVsync)
    .unwrap("couldn't create renderer")

var currentMusic {.used.}: MusicPtr
var musicVolume {.used.}: cint = 128
var numTicks: int
when VariableFps:
  var fps: int
  template adjustFps[T: SomeInteger](x: T): T = x * fps div ReferenceFps 
  template adjustFps[T: SomeFloat](x: T): T {.used.} = x * fps / ReferenceFps
else:
  template adjustFps(x): untyped = x

behavior:
  template render(state: Game) {.dirty.} =
    when defined(js):
      let windowWidth = cint canvas.width
      let windowHeight = cint canvas.height
    else:
      let windowSize = window.getSize()
      let (windowWidth, windowHeight) = windowSize
    renderImpl()

  template tick(state: Game) {.dirty.}
  proc key(state: Game, event: KeyboardEventPtr)
  proc keyRepeat(state: Game, event: KeyboardEventPtr)
  proc keyReleased(state: Game, event: KeyboardEventPtr)
  proc mouse(state: Game, event: MouseButtonEventPtr)
  proc windowResize(state: Game, event: WindowEventPtr)

inject:
  when defined(js):
    proc addListeners(state: Game) =
      document.body.addEventListener("keydown", proc (ev: Event) =
        let k = KeyboardEvent ev
        if not k.repeat:
          key(state, k)
        keyRepeat(state, k))
      document.body.addEventListener("keyup", proc (ev: Event) =
        keyReleased(state, ev.KeyboardEvent))
      document.body.addEventListener("mousedown", proc (ev: Event) =
        mouse(state, ev.MouseEvent))
      let window {.importc.}: Window
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
      window.addEventListener("resize", proc (ev: Event) =
        canvas.width = window.innerWidth
        canvas.height = window.innerHeight
        windowResize(state, UIEvent ev))
  else:
    proc listen(state: Game) =
      var event = defaultEvent
      while event.pollEvent():
        case event.kind
        of QuitEvent:
          switch(state, gsDone)
        of KeyDown:
          let key = event.key
          if not key.repeat:
            key(state, key)
          keyRepeat(state, key)
        of KeyUp:
          keyReleased(state, event.key)
        of MouseButtonDown:
          mouse(state, event.button)
        of WindowEvent:
          let win = event.window
          if win.event == WindowEvent_Resized:
            windowResize(state, win)
        else: discard
  
template line(x1, y1, x2, y2: cint) {.used.} =
  renderer.drawLine(x1, y1, x2, y2)

when defined(js):
  template drawColor(r, g, b, a: byte) {.used.} =
    context.fillStyle = cstring(color(r, g, b, a))
    context.strokeStyle = cstring(color(r, g, b, a))

  template drawColor(r, g, b: byte) =
    context.fillStyle = cstring(color(r, g, b))
    context.strokeStyle = cstring(color(r, g, b))

  template drawColor(col: Color) =
    context.fillStyle = cstring(col)
    context.strokeStyle = cstring(col)
  
  template setVolume(vol: cint) =
    musicVolume = vol
    currentMusic.setVolume(musicVolume.int)

  template draw(t: TexturePtr, x, y, w, h: cint) =
    context.drawImage(t, x, y, w, h)

  template draw(t: TexturePtr, x, y: cint) {.used.} =
    context.drawImage(t, x, y)

  template fillRect(x, y, w, h: cint) =
    context.fillRect(x, y, w, h)
  
  template drawRect(x, y, w, h: cint) =
    context.beginPath()
    context.rect(x, y, w, h)
    context.stroke()
else:
  template drawColor(r, g, b: byte, a = 255u8) =
    renderer.setDrawColor(r, g, b, a)

  template drawColor(col: Color) =
    renderer.setDrawColor(col)

  template loadTexture(file: cstring): TexturePtr =
    renderer.loadTexture(file)
  
  template setVolume(vol: cint) =
    musicVolume = vol
    discard volumeMusic(musicVolume)

  template draw(t: TexturePtr, x, y, w, h: cint) =
    renderer.draw(t, rect(x, y, w, h))

  template draw(t: TexturePtr, x, y: cint) {.used.} =
    renderer.draw(t, x, y)

  template fillRect(x, y, w, h: cint) =
    var rect = rect(x, y, w, h)
    renderer.fillRect(addr rect)

  template drawRect(x, y, w, h: cint) =
    var rect = rect(x, y, w, h)
    renderer.drawRect(addr rect)

include states/[initial, tetris]

addState Done

endScheme()

var game = GameObj(kind: gsInitial)
init(game)

when defined(js):
  {.emit: """
window.requestAnimationFrame =
  window.requestAnimationFrame ||
    window.webkitRequestAnimationFrame ||
    window.mozRequestAnimationFrame ||
    ((cb) => window.setTimeout(callback, 1000 / 60));
""".}
  import asyncjs
else:
  import std/monotimes
  from std/os import sleep
  {.pragma: async.}

proc singleLoop() =
  tick(game)
  drawColor(0, 0, 0)
  when defined(js):
    context.clearRect(0, 0, canvas.width, canvas.height)
  else:
    renderer.clear()
  render(game)
  when not defined(js):
    renderer.present()
  inc numTicks

proc mainLoop() {.async.} =
  when not defined(js):
    discard openAudio(44100, 0, 2, 4096)

    defer:
      closeAudio()
      sdl2.quit()

    var lastFrameTime: MonoTime
    while (lastFrameTime = getMonoTime(); game.kind != gsDone):
      listen(game)
      const nanowait = 1_000_000_000 div ReferenceFps
      let sleepTime = int((nanowait - getMonoTime().ticks + lastFrameTime.ticks) div 1_000_000)
      if sleepTime >= 0: sleep(sleepTime)
      singleLoop()
  else:
    var lastTimestamp: float
    addListeners(game)
    proc foo(timestamp: float) =
      fps = int(1000 / (timestamp - lastTimestamp))
      singleLoop()
      lastTimestamp = timestamp
      discard window.requestAnimationFrame(foo)
    discard window.requestAnimationFrame(foo)

when isMainModule: 
  when defined(js):
    discard mainLoop()

    when false:
      import jsconsole
      var lastNumTicks: int
      discard window.setInterval(proc () =
        console.log(numTicks - lastNumTicks)
        lastNumTicks = numTicks, 1000)
  else:
    mainLoop()
