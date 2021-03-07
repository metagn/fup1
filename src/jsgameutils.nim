import dom, strutils

type
  Audio* {.importc: "Audio".} = ref object
  Image* {.importc: "Image".} = ref object
  MusicPtr* = Audio
  TexturePtr* = Image
  KeyboardEventPtr* = KeyboardEvent
  MouseButtonEventPtr* = MouseEvent
  WindowEventPtr* = UIEvent
  Color* = distinct cstring

converter imageToElement*(im: TexturePtr): ImageElement {.importjs: "#".}

converter cintToInt*(im: cint): int {.importjs: "#".}
converter intToCint*(im: int): cint {.importjs: "#".}

template modsHeldDown*: bool =
  event.ctrlKey or event.metaKey or event.shiftKey or event.altKey

proc repeat*(ev: KeyboardEvent): bool {.importjs: "#.repeat".}

proc toCString*(x: auto): cstring {.importjs: "#.toString()".}
proc `&`*(x, y: cstring): cstring {.importjs: "(# + #)".}

proc loadTexture*(url: cstring): TexturePtr = 
  {.emit: """
  `result` = new Image();
  `result`.src = `url`;
  """.}

proc loadMus*(url: cstring): MusicPtr {.importjs: "new Audio(#)".}
proc playMusic*(mus: MusicPtr) {.importjs: "#.play()".}
proc pauseMusic*(mus: MusicPtr) {.importjs: "#.pause()".}

template stopMusic*(music: var MusicPtr) =
  music.pauseMusic()
  music = nil

proc setMusic*(music: var MusicPtr, file: cstring) =
  if not music.isNil:
    music.stopMusic()
  music = loadMus(file)

proc setLoop*(music: MusicPtr, d: bool) {.importjs: "#.loop = #".}

template loopMusic*(music: MusicPtr) =
  let m = music
  m.setLoop(true)
  m.playMusic()

template destroy*(p: MusicPtr | TexturePtr) = discard

proc setVolume*(music: MusicPtr, vol: int) =
  let vol2 = vol / 128
  {.emit: "`music`.volume = `vol2`".}

proc colorRt(r, g, b: uint8): Color =
  Color(cstring('#' & toHex((r.int shr 16) or (g.int shr 8) or b.int)))

template color*(r, g, b: uint8): Color =
  when compiles(static colorRt(r, g, b)):
    (static colorRt(r, g, b))
  else:
    colorRt(r, g, b)

proc colorRt(r, g, b, a: uint8): Color =
  Color(cstring"rgba(" & r.toCString & cstring"," & g.toCString & cstring"," &
    b.toCString & cstring"," & (a.int / 255).toCString & cstring")")

proc colorCt(r, g, b, a: uint8): Color =
  Color cstring "rgba(" & $r & ',' & $g & ',' & $b & ',' & $(a.int / 255) & ')'

template color*(r, g, b, a: uint8): Color =
  when compiles(static colorCt(r, g, b, a)):
    (static colorCt(r, g, b, a))
  else:
    colorRt(r, g, b, a)
