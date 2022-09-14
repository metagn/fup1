import bridge, backend, data

import states/[initial, tetris]

type None = object
type Done = object

type
  StateKind = enum
    gsNone, gsInitial, gsTetris, gsDone
  
  State = object
    case kind: StateKind
    of gsNone:
      none: None
    of gsInitial:
      initial: Initial
    of gsTetris:
      tetris: Tetris
    of gsDone:
      done: Done
  
  Game = ref object
    global: Global
    state: State

proc switch(game: Game, k: StateKind)

when true: # behaviors
  proc init(game: Game, state: var State, global: Global) =
    case state.kind
    of gsNone: init(state.none, global)
    of gsInitial: init(state.initial, global)
    of gsTetris: init(state.tetris, global)
    of gsDone: init(state.done, global)

  proc finish(game: Game, state: State, global: Global) =
    case state.kind
    of gsNone: finish(state.none, global)
    of gsInitial: finish(state.initial, global)
    of gsTetris: finish(state.tetris, global)
    of gsDone: finish(state.done, global)

  proc tick(game: Game, state: State, global: Global) =
    case state.kind
    of gsNone: tick(state.none, global)
    of gsInitial: tick(state.initial, global)
    of gsTetris: tick(state.tetris, global)
    of gsDone: tick(state.done, global)

  proc render(game: Game, state: State, global: Global, windowWidth, windowHeight: cint) =
    case state.kind
    of gsNone: render(state.none, global, windowWidth, windowHeight)
    of gsInitial: render(state.initial, global, windowWidth, windowHeight)
    of gsTetris: render(state.tetris, global, windowWidth, windowHeight)
    of gsDone: render(state.done, global, windowWidth, windowHeight)

  proc key(game: Game, state: State, global: Global, event: KeyboardEventPtr) =
    case state.kind
    of gsNone: key(state.none, global, event)
    of gsInitial: key(state.initial, global, event)
    of gsTetris: key(state.tetris, global, event)
    of gsDone: key(state.done, global, event)

  proc keyRepeat(game: Game, state: State, global: Global, event: KeyboardEventPtr) =
    case state.kind
    of gsNone: keyRepeat(state.none, global, event)
    of gsInitial: keyRepeat(state.initial, global, event)
    of gsTetris: keyRepeat(state.tetris, global, event)
    of gsDone: keyRepeat(state.done, global, event)

  proc keyReleased(game: Game, state: State, global: Global, event: KeyboardEventPtr) =
    case state.kind
    of gsNone: keyReleased(state.none, global, event)
    of gsInitial: keyReleased(state.initial, global, event)
    of gsTetris: keyReleased(state.tetris, global, event)
    of gsDone: keyReleased(state.done, global, event)

when true: # behaviors again
  proc init(game: Game) =
    init(game, game.state, game.global)

  proc finish(game: Game) =
    finish(game, game.state, game.global)

  proc tick(game: Game) =
    tick(game, game.state, game.global)

  proc render(game: Game) =
    when canvasBackend:
      let windowWidth = cint game.global.canvas.width
      let windowHeight = cint game.global.canvas.height
    when sdlBackend:
      let windowSize = game.global.window.getSize()
      let (windowWidth, windowHeight) = windowSize
    render(game, game.state, game.global, windowWidth, windowHeight)

  proc key(game: Game, event: KeyboardEventPtr) =
    key(game, game.state, game.global, event)

  proc keyRepeat(game: Game, event: KeyboardEventPtr) =
    keyRepeat(game, game.state, game.global, event)

  proc keyReleased(game: Game, event: KeyboardEventPtr) =
    keyReleased(game, game.state, game.global, event)

proc switch(game: Game, k: StateKind) =
  finish(game)
  game.state = State(kind: k)
  init(game)

proc init(game: var Game) =
  game = Game()
  game.global = newGlobal()

  when canvasBackend:
    game.global.canvas = CanvasElement getElementById("fup1")
    game.global.context = game.global.canvas.getContext2d()

  when sdlBackend:
    sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)
      .unwrap("couldn't initialize SDL")
    setHint("SDL_RENDER_SCALE_QUALITY", "2")
      .unwrap("couldn't set SDL render scale quality")

    game.global.window = createWindow(
      "The Tetry Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
      ReferenceWidth, ReferenceHeight, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_OPENGL)
      .unwrap("couldn't create window")
    game.global.renderer = game.global.window.createRenderer(-1,
      Renderer_Accelerated or Renderer_PresentVsync)
      .unwrap("couldn't create renderer")
    
    discard openAudio(44100, 0, 2, 4096)
  
  switch(game, gsInitial)

proc finish(game: var Game) =
  when sdlBackend:
    closeAudio()
    sdl2.quit()

when canvasBackend:
  proc addListeners(game: Game) =
    document.body.addEventListener("keydown", proc (ev: Event) =
      let k = KeyboardEvent ev
      if not k.repeat:
        key(game, k)
      keyRepeat(game, k))
    document.body.addEventListener("keyup", proc (ev: Event) =
      keyReleased(game, ev.KeyboardEvent))
    let window {.importc.}: Window
    game.global.canvas.width = window.innerWidth
    game.global.canvas.height = window.innerHeight
when sdlBackend:
  proc listen(game: Game) =
    var event = defaultEvent
    while event.pollEvent():
      case event.kind
      of QuitEvent:
        switch(game, gsDone)
      of KeyDown:
        let key = event.key
        if not key.repeat:
          key(game, key)
        keyRepeat(game, key)
      of KeyUp:
        keyReleased(game, event.key)
      else: discard

from states/common import preRender, postRender

proc singleLoop(game: Game) =
  tick(game)
  preRender(game.global)
  render(game)
  postRender(game.global)
  inc game.global.numTicks

when defined(js):
  import asyncjs

  # requestAnimationFrame polyfill:
  {.emit: """
window.requestAnimationFrame =
  window.requestAnimationFrame ||
    window.webkitRequestAnimationFrame ||
    window.mozRequestAnimationFrame ||
    ((cb) => window.setTimeout(callback, 1000 / 60));
""".}

  proc mainLoop(game: Game) {.async, discardable.} =
    addListeners(game)
    var lastTimestamp: float
    proc frame(timestamp: float) =
      game.global.fps = int(1000 / (timestamp - lastTimestamp))
      singleLoop(game)
      lastTimestamp = timestamp
      discard window.requestAnimationFrame(frame)
    discard window.requestAnimationFrame(frame)
else:
  import std/monotimes
  from std/os import sleep
  proc mainLoop(game: Game) =
    var lastFrameTime: MonoTime
    while (lastFrameTime = getMonoTime(); game.state.kind != gsDone):
      listen(game)
      const nanowait = 1_000_000_000 div ReferenceFps
      let sleepTime = int((nanowait - getMonoTime().ticks + lastFrameTime.ticks) div 1_000_000)
      if sleepTime >= 0: sleep(sleepTime)
      singleLoop(game)

proc main() =
  var game: Game

  init(game)
  defer: finish(game)

  mainLoop(game)

when isMainModule:
  main()
