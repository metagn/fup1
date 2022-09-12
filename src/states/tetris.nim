import common

import random, math

type PieceKind = enum
  tetNone, tetI, tetJ, tetL, tetO, tetS, tetZ, tetT
  
const
  Columns = 10
  Rows = 30
  VisibleRows = 20
  VisibleStart = Rows - VisibleRows
  
  pieceColors: array[PieceKind, Color] = [
    tetNone: color(0, 0, 0, 0),
    tetI: color(0, 127, 255, 255),
    tetJ: color(0, 0, 255, 255),
    tetL: color(255, 127, 0, 255),
    tetO: color(255, 255, 0, 255),
    tetS: color(0, 255, 127, 255),
    tetZ: color(255, 0, 0, 255),
    tetT: color(255, 0, 255, 255)
  ]

  pieceExtensions: array[PieceKind, seq[tuple[x, y: int]]] = [
    tetNone: @[],
    tetI: @[(0, 1), (0, 2), (0, 3)],
    tetJ: @[(0, -1), (1, -1), (0, 1)],
    tetL: @[(-1, -1), (0, -1), (0, 1)],
    tetO: @[(0, 1), (1, 0), (1, 1)],
    tetS: @[(-1, 1), (0, 1), (1, 0)],
    tetZ: @[(-1, 0), (0, 1), (1, 1)],
    tetT: @[(-1, 0), (0, 1), (1, 0)]
  ]

type
  Coord = distinct range[0 .. Columns * Rows - 1]
  Column = range[0 .. Columns - 1]
  Row = range[0 .. Rows - 1]
  Rotation = range[0..3]
  
  Piece = object
    kind: PieceKind
    pos: Coord
    rot: Rotation

proc contains[U](T: type range, x: U): bool = x in low(T) .. high(T)
proc coord(x: Column, y: Row): Coord {.inline.} = Coord(y * Columns + x)
proc column(c: Coord): Column {.inline.} = c.int mod Columns
proc row(c: Coord): Row {.inline.} = c.int div Columns
proc `$`(c: Coord): string {.used.} = $(column(c), row(c))
proc rot(x, y: int, q: Rotation): (int, int) =
  case q
  of 0: (x, y)
  of 1: (y, -x)
  of 2: (-x, -y)
  of 3: (-y, x)

proc plusRot(a: Coord, x, y: int, q: Rotation): (int, int) =
  let (rotx, roty) = rot(x, y, q)
  result = (column(a) + rotx, row(a) + roty)

iterator coveredCoords(piece: Piece, outOfBounds: var bool): Coord =
  if piece.kind != tetNone: yield piece.pos
  for (x, y) in pieceExtensions[piece.kind].items:
    let (col, row) = plusRot(piece.pos, x, y, piece.rot)
    if col in Column and row in Row:
      yield coord(col, row)
    else:
      outOfBounds = true
      break

iterator coveredCoords(piece: Piece): Coord =
  if piece.kind != tetNone: yield piece.pos
  for (x, y) in pieceExtensions[piece.kind].items:
    let (c, r) = piece.pos.plusRot(x, y, piece.rot)
    yield coord(c, r)
  
proc overlaps(board: array[Coord, PieceKind], piece: Piece): bool =
  result = false
  for c in piece.coveredCoords:
    if board[c] != tetNone:
      return true

proc overlapsOrOOB(board: array[Coord, PieceKind], piece: Piece): bool =
  result = false
  for c in piece.coveredCoords(result):
    if result or board[c] != tetNone:
      return true

proc initPiece(kind: PieceKind): Piece =
  const minDims = (proc: array[PieceKind, (int, int)] =
    for pk, dim in result.mpairs:
      for jj in pieceExtensions[pk]:
        if jj[0] < dim[0]: dim[0] = jj[0]
        if jj[1] < dim[1]: dim[1] = jj[1])()
  result.kind = kind
  result.pos = coord(-minDims[kind][0], -minDims[kind][1])

type Tetris* = ref object
  board: array[Coord, PieceKind] # array of rows, top to bottom

  nextPieces: array[4, Piece]

  piece: Piece

  pieceDropTicking: bool
  pieceDropTick, pieceDropTime: int
  pieceDropTickMultiplier: int
  pieceDropRetry, pieceDropRetries: int

  holdPiece: Piece
  justHeld: bool
  randBuffer: array[len(tetI..tetT), PieceKind]
  randBufferPos: int

proc randPieceKind(state: Tetris): PieceKind =
  if state.randBufferPos == len(state.randBuffer):
    state.randBufferPos = 0
    state.randBuffer = [tetI, tetJ, tetL, tetO, tetS, tetZ, tetT]
    shuffle state.randBuffer
  result = state.randBuffer[state.randBufferPos]
  inc state.randBufferPos

proc nextPiece(state: Tetris): Piece =
  result = state.nextPieces[0]
  state.nextPieces[0..^2] = state.nextPieces[1..^1]
  state.nextPieces[^1] = initPiece(state.randPieceKind)

proc spawnPiece(state: Tetris, initial = nextPiece(state)) =
  state.piece = initial
  if state.piece.kind == tetNone:
    state.piece.kind = rand(tetI..tetT)
  state.piece.pos = coord(Columns div 2, if state.piece.kind in {tetJ, tetL}: VisibleStart + 1 else: VisibleStart)
  while state.board.overlaps(state.piece):
    state.piece.pos = Coord(state.piece.pos.int - Columns)
  state.pieceDropTick = 0

from os import fileExists

proc init*(state: var Tetris, global: Global) =
  state = Tetris()
  block pieceDrop:
    state.pieceDropTicking = true
    state.pieceDropTick = 0
    state.pieceDropTime = 120
    state.pieceDropTickMultiplier = 1
    state.pieceDropRetry = 0
    state.pieceDropRetries = 1
  state.randBufferPos = len(tetI..tetT)

  randomize()
  for np in state.nextPieces.mitems:
    np = initPiece(state.randPieceKind)
  spawnPiece(state)
  # js will only fail in console
  if (when defined(js): true else: fileExists("assets/music.ogg")):
    setMusic(global.currentMusic, "assets/music.ogg")
  loopMusic(global.currentMusic)

proc finish*(state: Tetris, global: Global) =
  stopMusic(global.currentMusic)

proc rotate(state: Tetris, forward: bool) =
  let oldRot: Rotation = state.piece.rot
  let newRot: Rotation =
    if forward:
      if oldRot == high Rotation: low Rotation else: oldRot + 1
    else:
      if oldRot == low Rotation: high Rotation else: oldRot - 1
  # check if rotation is valid
  var newPiece = state.piece
  newPiece.rot = newRot
  var outOfBounds: bool
  for _ in newPiece.coveredCoords(outOfBounds): discard
  var i = 1
  while outOfBounds:
    outOfBounds = false
    # check left first
    let (col0, row0) = (column(newPiece.pos), row(newPiece.pos))
    var oneInside = false
    if col0 - i in Column:
      oneInside = true
      newPiece.pos = coord(col0 - i, row0)
      for _ in newPiece.coveredCoords(outOfBounds): discard
    else: outOfBounds = true
    if outOfBounds:
      outOfBounds = false
      # check right second
      if col0 + i in Column:
        oneInside = true
        newPiece.pos = coord(col0 + i, row0)
        for _ in newPiece.coveredCoords(outOfBounds): discard
      else: outOfBounds = true
    if oneInside: inc i
    else: break
  if outOfBounds: return
  while state.board.overlaps(newPiece):
    # jump up
    newPiece.pos = Coord(newPiece.pos.int - Columns)
  state.piece = newPiece
  
proc drop(state: Tetris, spawned: var bool) =
  var newPiece = state.piece
  var maxRow = 0
  for c in state.piece.coveredCoords:
    if row(c) > maxRow: maxRow = row(c)
  if maxRow == high Row:
    spawned = true
  else:
    newPiece.pos = Coord(newPiece.pos.int + Columns)
    spawned = state.board.overlaps(newPiece)
  if spawned:
    if state.pieceDropRetry < state.pieceDropRetries:
      inc state.pieceDropRetry
    else:
      state.pieceDropRetry = 0
      state.justHeld = false
      for c in state.piece.coveredCoords:
        state.board[c] = state.piece.kind
      spawnPiece(state)
  else:
    state.piece = newPiece

proc drop(state: Tetris) =
  var spawned: bool
  drop(state, spawned)

template tick*(state: Tetris, global: Global) =
  if state.pieceDropTicking:
    inc state.pieceDropTick
    if state.pieceDropTick * state.pieceDropTickMultiplier >= adjustFps(state.pieceDropTime):
      drop(state)
      state.pieceDropTick = 0
    for r in 0..<Rows:
      var anyEmpty = false
      for c in 0..<Columns:
        if state.board[coord(c, r)] == tetNone:
          anyEmpty = true
          break
      if not anyEmpty:
        for ri in countdown(r, 0):
          for ci in 0..<Columns:
            if ri == 0:
              state.board[coord(ci, ri)] = tetNone
            else:
              swap state.board[coord(ci, ri)], state.board[coord(ci, ri - 1)]
    var maxRow = 0
    for c in state.piece.coveredCoords:
      if row(c) > maxRow: maxRow = row(c)
    if maxRow < VisibleStart:
      game.switch(gsInitial) # lost

proc render*(state: Tetris, global: Global, windowWidth, windowHeight: cint) =
  const TilePix = ReferenceHeight div VisibleRows
  const ColumnStart = (ReferenceWidth - TilePix * Columns) div 2
  const ColumnEnd = ReferenceWidth - ColumnStart
  const Div23 = ColumnStart / 23
  let (scaledWindowWidth, scaledWindowHeight) = block:
    let a = windowWidth / ReferenceWidth
    let b = windowHeight / ReferenceHeight
    if a != b:
      let newRatio = min(a, b)
      (newRatio * ReferenceWidth, newRatio * ReferenceHeight)
    else:
      (windowWidth.float, windowHeight.float)
  let startX = (windowWidth.float - scaledWindowWidth) / 2
  let startY = (windowHeight.float - scaledWindowHeight) / 2
  template scaleX[T: SomeFloat](f: T): T = f * scaledWindowWidth / ReferenceWidth
  template scaleY[T: SomeFloat](f: T): T = f * scaledWindowHeight / ReferenceHeight
  template scaleX[T: SomeInteger](f: T): T = T(f.float * scaledWindowWidth / ReferenceWidth)
  template scaleY[T: SomeInteger](f: T): T = T(f.float * scaledWindowHeight / ReferenceHeight)
  template translateX[T: SomeFloat](f: T): T = startX + scaleX(f)
  template translateY[T: SomeFloat](f: T): T = startY + scaleX(f)
  template translateX[T: SomeInteger](f: T): T = T(startX) + scaleY(f)
  template translateY[T: SomeInteger](f: T): T = T(startY) + scaleY(f)
  const guideColor = color(80, 80, 80, 255)
  let scaledTileWidth = cint ceil scaleX TilePix.float
  let scaledTileHeight = cint ceil scaleY TilePix.float

  # next pieces:
  drawColor guideColor
  const NextPieceStartX = ColumnEnd + 4 * 23
  const NextPieceStartY = 3 * Div23
  drawRect(
    cint translateX NextPieceStartX,
    cint translateY NextPieceStartY,
    cint ceil scaleX 5 * Div23,
    cint ceil scaleY 17 * Div23)
  for i, p in state.nextPieces:
    drawColor pieceColors[p.kind]
    var maxX, maxY = 0
    for c in coveredCoords(p):
      if column(c) > maxX: maxX = column(c)
      if row(c) > maxY: maxY = row(c)
    const PieceArea = 3 * Div23
    const PieceDist = Div23
    let
      width = maxX + 1
      height = maxY + 1
      unit = PieceArea / max(width, height).float
      tileWidth = cint ceil scaleX unit
      tileHeight = cint ceil scaleY unit
      tileXStart = NextPieceStartX + PieceDist + (PieceArea - width.float * unit) / 2
      tileYStart = NextPieceStartY + PieceDist + i.float * (PieceArea + PieceDist) + (PieceArea - height.float * unit) / 2
    for c in coveredCoords(p):
      let x = cint translateX column(c).float * unit + tileXStart
      let y = cint translateY row(c).float * unit + tileYStart
      fillRect x, y, tileWidth, tileHeight

  # hold pieces:
  drawColor guideColor
  drawRect(
    cint translateX 13 * Div23,
    cint translateY 3 * Div23,
    cint ceil scaleX 5 * Div23,
    cint ceil scaleY 5 * Div23)
  if state.holdPiece.kind != tetNone:
    const HoldPieceStart = 14 * Div23
    const unavailableHoldPieceColor = color(60, 60, 60, 255)
    drawColor if state.justHeld: unavailableHoldPieceColor else: pieceColors[state.holdPiece.kind]
    var maxX, maxY = 0
    for c in coveredCoords(state.holdPiece):
      if column(c) > maxX: maxX = column(c)
      if row(c) > maxY: maxY = row(c)
    const HoldPieceArea = 3 * Div23
    let
      width = maxX + 1
      height = maxY + 1
      unit = HoldPieceArea / max(width, height).float
      tileWidth = cint ceil scaleX unit
      tileHeight = cint ceil scaleY unit
      tileXStart = HoldPieceStart + (HoldPieceArea - width.float * unit) / 2
      tileYStart = 4 * Div23 + (HoldPieceArea - height.float * unit) / 2
    for c in coveredCoords(state.holdPiece):
      let x = cint translateX column(c).float * unit + tileXStart
      let y = cint translateY row(c).float * unit + tileYStart
      fillRect x, y, tileWidth, tileHeight
  
  # board:
  for rowI in VisibleStart..<Rows:
    for colI in 0..<Columns:
      let p = state.board[coord(colI, rowI)]
      let x = cint translateX colI * TilePix + ColumnStart
      let y = cint translateY (rowI - VisibleStart) * TilePix
      if p != tetNone:
        drawColor pieceColors[p]
        fillRect x, y, scaledTileWidth, scaledTileHeight
      drawColor guideColor
      drawRect(x, y, scaledTileWidth, scaledTileHeight)
  
  # shadow piece:
  var shadowPiece = state.piece
  while true:
    let oldPos = shadowPiece.pos
    let newRow = row(oldPos) + 1
    if newRow notin Row or (shadowPiece.pos = coord(column(oldPos), newRow); state.board.overlapsOrOOB(shadowPiece)):
      shadowPiece.pos = oldPos
      break
  const shadowColor = color(200, 200, 200, 255)
  drawColor shadowColor
  for c in coveredCoords(shadowPiece):
    if row(c) >= VisibleStart:
      let x = cint translateX column(c) * TilePix + ColumnStart
      let y = cint translateY (row(c) - VisibleStart) * TilePix
      fillRect x, y, scaledTileWidth, scaledTileHeight
  
  # real piece:
  drawColor pieceColors[state.piece.kind]
  for c in coveredCoords(state.piece):
    if row(c) >= VisibleStart:
      let x = cint translateX column(c) * TilePix + ColumnStart
      let y = cint translateY (row(c) - VisibleStart) * TilePix
      fillRect x, y, scaledTileWidth, scaledTileHeight

template key*(state: Tetris, global: Global, event: KeyboardEventPtr) =
  caseCOrJs (event.keysym.scancode, $event.key):
  of (SDL_SCANCODE_X, "x"):
    rotate(state, forward = true)
  of (SDL_SCANCODE_Z, "z"):
    rotate(state, forward = false)
  of (SDL_SCANCODE_C, "c"):
    if not state.justHeld:
      state.justHeld = true
      let oldHoldPiece =
        if state.holdPiece.kind != tetNone:
          state.holdPiece
        else:
          nextPiece(state)
      state.holdPiece = state.piece
      var
        minX = column(state.holdPiece.pos)
        minY = row(state.holdPiece.pos)
      for c in coveredCoords(state.holdPiece):
        if column(c) < minX: minX = column(c)
        if row(c) < minY: minY = row(c)
      state.holdPiece.pos = coord(column(state.holdPiece.pos) - minX, row(state.holdPiece.pos) - minY)
      spawnPiece(state, oldHoldPiece)
  of (SDL_SCANCODE_DOWN, "ArrowDown"), (_, "Down"):
    state.pieceDropTime = 10
    state.pieceDropRetries = 3
  of (SDL_SCANCODE_UP, "ArrowUp"), (_, "Up"):
    state.pieceDropRetry = state.pieceDropRetries
    var spawned: bool
    while not spawned: drop(state, spawned)
    state.pieceDropTick = 0
  of (SDL_SCANCODE_D, "d"):
    inc state.pieceDropTickMultiplier
  of (SDL_SCANCODE_S, "s"):
    state.pieceDropTickMultiplier = max(0, state.pieceDropTickMultiplier - 1)
  of (SDL_SCANCODE_I, "i"), (_, "ı"):
    setVolume(max(0, global.musicVolume - 16))
  of (SDL_SCANCODE_O, "o"):
    setVolume(min(128, global.musicVolume + 16))
  of (SDL_SCANCODE_ESCAPE, "Escape"):
    game.switch(gsInitial)
  else: discard

proc keyRepeat*(state: Tetris, global: Global, event: KeyboardEventPtr) =
  caseCOrJs (event.keysym.scancode, $event.key):
  of (SDL_SCANCODE_LEFT, "ArrowLeft"), (_, "Left"):
    var minCol = high Column
    for c in state.piece.coveredCoords:
      if column(c) < minCol: minCol = column(c)
    if minCol != low Column:
      var newPiece = state.piece
      newPiece.pos = Coord(newPiece.pos.int - 1)
      if not state.board.overlaps(newPiece):
        state.piece = newPiece
  of (SDL_SCANCODE_RIGHT, "ArrowRight"), (_, "Right"):
    var maxCol = 0
    for c in state.piece.coveredCoords:
      if column(c) > maxCol: maxCol = column(c)
    if maxCol != high Column:
      var newPiece = state.piece
      newPiece.pos = Coord(newPiece.pos.int + 1)
      if not state.board.overlaps(newPiece):
        state.piece = newPiece
  else: discard

proc keyReleased*(state: Tetris, global: Global, event: KeyboardEventPtr) =
  caseCOrJs (event.keysym.scancode, $event.key):
  of (SDL_SCANCODE_DOWN, "ArrowDown"), (_, "Down"):
    state.pieceDropTime = 120
    state.pieceDropRetries = 1
  else: discard

when false:
  windowResize:
    let (width, height) = window.getSize
    let a = width / ReferenceWidth
    let b = height / ReferenceHeight
    if a != b:
      let min = min(a, b)
      window.setSize cint round min * ReferenceWidth, cint round min * ReferenceHeight
