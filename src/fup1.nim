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

proc switch(game: Game, k: StateKind) =
  finish(game.state, game.global)
  game.state = State(kind: k)
  init(game.state, game.global)

proc newGame(): Game =
  result = Game()
  result.global = newGlobal()
  when defined(js):
    result.global.canvas = CanvasElement getElementById("fup1")
    result.global.context = result.global.canvas.getContext2d()
  else:
    sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS or INIT_AUDIO)
      .unwrap("couldn't initialize SDL")
    setHint("SDL_RENDER_SCALE_QUALITY", "2")
      .unwrap("couldn't set SDL render scale quality")

    result.global.window = createWindow(
      "The Tetry Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
      ReferenceWidth, ReferenceHeight, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_OPENGL)
      .unwrap("couldn't create window")
    result.global.renderer = result.global.window.createRenderer(-1,
      Renderer_Accelerated or Renderer_PresentVsync)
      .unwrap("couldn't create renderer")

when true: # behaviors again
  proc init(game: Game) =
    init(game, game.state, game.global)

  proc finish(game: Game) =
    finish(game, game.state, game.global)

  proc tick(game: Game) =
    tick(game, game.state, game.global)

  proc render(game: Game) =
    when defined(js):
      let windowWidth = cint game.global.canvas.width
      let windowHeight = cint game.global.canvas.height
    else:
      let windowSize = game.global.window.getSize()
      let (windowWidth, windowHeight) = windowSize
    render(game, game.state, game.global, windowWidth, windowHeight)

  proc key(game: Game, event: KeyboardEventPtr) =
    key(game, game.state, game.global, event)

  proc keyRepeat(game: Game, event: KeyboardEventPtr) =
    keyRepeat(game, game.state, game.global, event)

  proc keyReleased(game: Game, event: KeyboardEventPtr) =
    keyReleased(game, game.state, game.global, event)

when defined(js):
  proc addListeners(game: Game) =
    document.body.addEventListener("keydown", proc (ev: Event) =
      let k = KeyboardEvent ev
      if not k.repeat:
        key(game, k)
      keyRepeat(game, k))
    document.body.addEventListener("keyup", proc (ev: Event) =
      keyReleased(game, ev.KeyboardEvent))
    when false:
      document.body.addEventListener("mousedown", proc (ev: Event) =
        mouse(game, ev.MouseEvent))
    let window {.importc.}: Window
    game.global.canvas.width = window.innerWidth
    game.global.canvas.height = window.innerHeight
    when false:
      window.addEventListener("resize", proc (ev: Event) =
        game.global.canvas.width = window.innerWidth
        game.global.canvas.height = window.innerHeight
        windowResize(game, UIEvent ev))
else:
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
      of MouseButtonDown:
        when false:
          mouse(game, event.button)
      of WindowEvent:
        when false:
          let win = event.window
          if win.event == WindowEvent_Resized:
            windowResize(game, win)
      else: discard

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

from states/common import preRender, postRender

proc singleLoop(game: Game) =
  tick(game)
  preRender(game.global)
  render(game)
  postRender(game.global)
  inc game.global.numTicks

proc mainLoop(game: Game) {.async.} =
  when not defined(js):
    discard openAudio(44100, 0, 2, 4096)

    defer:
      closeAudio()
      sdl2.quit()

    var lastFrameTime: MonoTime
    while (lastFrameTime = getMonoTime(); game.state.kind != gsDone):
      listen(game)
      const nanowait = 1_000_000_000 div ReferenceFps
      let sleepTime = int((nanowait - getMonoTime().ticks + lastFrameTime.ticks) div 1_000_000)
      if sleepTime >= 0: sleep(sleepTime)
      singleLoop(game)
  else:
    var lastTimestamp: float
    addListeners(game)
    proc foo(timestamp: float) =
      game.global.fps = int(1000 / (timestamp - lastTimestamp))
      singleLoop(game)
      lastTimestamp = timestamp
      discard window.requestAnimationFrame(foo)
    discard window.requestAnimationFrame(foo)

proc main() =
  var game = newGame()
  init(game)
  when defined(js):
    discard mainLoop(game)

    when false:
      import jsconsole
      var lastNumTicks: int
      discard window.setInterval(proc () =
        console.log(numTicks - lastNumTicks)
        lastNumTicks = numTicks, 1000)
  else:
    mainLoop(game)

when isMainModule:
  main()
