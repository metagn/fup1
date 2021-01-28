import schemes, sdlutils, sdl2, sdl2/[image, mixer]

initScheme Game, {scfNoneState, scfVar, scfDeepRef}

proc init(state: Game) {.behavior, init.}
proc finish(state: Game) {.behavior.}

inject:
  template switch(state: Game, k: GameKind) {.dirty.} =
    finish(state)
    state = GameObj(kind: k)
    init(state)

sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)
  .unwrap("couldn't initialize SDL")
setHint("SDL_RENDER_SCALE_QUALITY", "2")
  .unwrap("couldn't set SDL render scale quality")

let window = createWindow(
  "BrokenAce's Time Machine", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
  600, 800, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_OPENGL)
  .unwrap("couldn't create window")
let renderer = window.createRenderer(-1,
  Renderer_Accelerated or Renderer_PresentVsync)
  .unwrap("couldn't create renderer")

var currentMusic {.used.}: MusicPtr

behavior:
  template render(state: Game) {.dirty.} =
    let windowSize = window.getSize()
    let (windowWidth, windowHeight) = windowSize
    renderImpl()

  template tick(state: Game) {.dirty.}
  proc key(state: Game, event: KeyboardEventPtr)
  proc keyRepeat(state: Game, event: KeyboardEventPtr)
  proc keyReleased(state: Game, event: KeyboardEventPtr)
  proc mouse(state: Game, event: MouseButtonEventPtr)
  proc windowResize(state: Game, event: WindowEventPtr)
  proc otherEvent(state: Game, event: Event)

inject:
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
        else:
          otherEvent(state, event)
      else:
        otherEvent(state, event)
  
template line(x1, y1, x2, y2: cint) {.used.} =
  renderer.drawLine(x1, y1, x2, y2)

template drawColor(r, g, b: byte, a = 255u8) =
  renderer.setDrawColor(r, g, b, a)

template drawColor(col: Color) =
  renderer.setDrawColor(col)

template fillRect(x, y, w, h: cint) =
  var rect = rect(x, y, w, h)
  renderer.fillRect(addr rect)

include states/[initial, tetris]

addState Done

endScheme()

var state: GameObj

discard openAudio(0, 0, 2, 4096)
switch(state, gsInitial)

import times, os
var lastFrameTime = cpuTime()
while state.kind != gsDone:
  listen(state)
  let interval = cpuTime() - lastFrameTime
  let sleepTime = int((1 / 120 - interval.float) * 1000)
  if sleepTime >= 0: sleep(sleepTime)
  tick(state)
  drawColor(0, 0, 0)
  renderer.clear()
  render(state)
  renderer.present()
  lastFrameTime = cpuTime()

closeAudio()
sdl2.quit()