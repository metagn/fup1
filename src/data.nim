import backend

const
  ReferenceWidth* = 960
  ReferenceHeight* = 540
  ReferenceFps* = 120
  VariableFps* = defined(js)

when VariableFps:
  template adjustFps*[T: SomeInteger](x: T): T = x * global.fps div ReferenceFps 
  template adjustFps*[T: SomeFloat](x: T): T {.used.} = x * global.fps / ReferenceFps
else:
  template adjustFps*(x): untyped = x

type Global* = ref object
  currentMusic*: MusicPtr
  musicVolume*: cint
  numTicks*: int
  when VariableFps:
    fps*: int
  when canvasBackend:
    canvas*: CanvasElement
    context*: CanvasContext
  when sdlBackend:
    window*: WindowPtr
    renderer*: RendererPtr

proc newGlobal*(): Global =
  result = Global(musicVolume: 128)

# behaviors
type DefaultState = auto
proc init*(state: var DefaultState, global: Global) = discard
proc finish*(state: DefaultState, global: Global) = discard
proc tick*(state: DefaultState, global: Global) = discard
proc render*(state: DefaultState, global: Global, windowWidth, windowHeight: cint) = discard
proc key*(state: DefaultState, global: Global, event: KeyboardEventPtr) = discard
proc keyRepeat*(state: DefaultState, global: Global, event: KeyboardEventPtr) = discard
proc keyReleased*(state: DefaultState, global: Global, event: KeyboardEventPtr) = discard
