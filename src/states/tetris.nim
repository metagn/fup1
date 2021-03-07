import random, math

state Tetris:
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
  proc `$`(c: Coord): string {.used.} = $(c.column, c.row)
  proc rot(x, y: int, q: Rotation): (int, int) =
    case q
    of 0: (x, y)
    of 1: (y, -x)
    of 2: (-x, -y)
    of 3: (-y, x)

  proc plusRot(a: Coord, x, y: int, q: Rotation): (int, int) =
    let (rotx, roty) = rot(x, y, q)
    result = (a.column + rotx, a.row + roty)

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

  var
    board: array[Coord, PieceKind] # array of rows, top to bottom

    nextPieces: array[4, Piece]

    piece: Piece

    pieceDropTicking = true
    pieceDropTick = 0
    pieceDropTime = 120
    pieceDropTickMultiplier = 1
    pieceDropRetry = 0
    pieceDropRetries = 1

    holdPiece: Piece
    justHeld = false
    randBuffer: array[len(tetI..tetT), PieceKind]
    randBufferPos = len(tetI..tetT)
  
  proc randPieceKind(state: Tetris): PieceKind {.member.} =
    if randBufferPos == len(randBuffer):
      randBufferPos = 0
      randBuffer = [tetI, tetJ, tetL, tetO, tetS, tetZ, tetT]
      shuffle randBuffer
    result = randBuffer[randBufferPos]
    inc randBufferPos

  proc initPiece(kind: PieceKind): Piece =
    const minDims = (proc: array[PieceKind, (int, int)] =
      for pk, dim in result.mpairs:
        for jj in pieceExtensions[pk]:
          if jj[0] < dim[0]: dim[0] = jj[0]
          if jj[1] < dim[1]: dim[1] = jj[1])()
    result.kind = kind
    result.pos = coord(-minDims[kind][0], -minDims[kind][1])

  proc nextPiece(state: Tetris): Piece {.member.} =
    result = nextPieces[0]
    nextPieces[0..^2] = nextPieces[1..^1]
    nextPieces[^1] = initPiece(state.randPieceKind)

  proc spawnPiece(state: Tetris, initial = state.nextPiece()) {.member.} =
    piece = initial
    if piece.kind == tetNone:
      piece.kind = rand(tetI..tetT)
    piece.pos = coord(Columns div 2, if piece.kind in {tetJ, tetL}: VisibleStart + 1 else: VisibleStart)
    while board.overlaps(piece):
      piece.pos = Coord(piece.pos.int - Columns)
    pieceDropTick = 0

  init:
    randomize()
    for np in nextPieces.mitems:
      np = initPiece(state.tetris.randPieceKind)
    state.tetris.spawnPiece()
    setMusic(currentMusic, "assets/music.ogg")
    loopMusic(currentMusic)
  
  finish: stopMusic(currentMusic)
  
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
  
  proc rotate(state: Tetris, forward: bool) {.member.} =
    let oldRot: Rotation = piece.rot
    let newRot: Rotation =
      if forward:
        if oldRot == high Rotation: low Rotation else: oldRot + 1
      else:
        if oldRot == low Rotation: high Rotation else: oldRot - 1
    # check if rotation is valid
    var newPiece = piece
    newPiece.rot = newRot
    var outOfBounds: bool
    for _ in newPiece.coveredCoords(outOfBounds): discard
    var i = 1
    while outOfBounds:
      outOfBounds = false
      # check left first
      let (col0, row0) = (newPiece.pos.column, newPiece.pos.row)
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
    while board.overlaps(newPiece):
      # jump up
      newPiece.pos = Coord(newPiece.pos.int - Columns)
    piece = newPiece
    
  proc drop(state: Tetris, spawned: var bool) {.member.} =
    var newPiece = piece
    var maxRow = 0
    for c in piece.coveredCoords:
      if c.row > maxRow: maxRow = c.row
    if maxRow == high Row:
      spawned = true
    else:
      newPiece.pos = Coord(newPiece.pos.int + Columns)
      spawned = board.overlaps(newPiece)
    if spawned:
      if pieceDropRetry < pieceDropRetries:
        inc pieceDropRetry
      else:
        pieceDropRetry = 0
        justHeld = false
        for c in piece.coveredCoords:
          board[c] = piece.kind
        state.spawnPiece()
    else:
      piece = newPiece
  
  proc drop(state: Tetris) {.member.} =
    var spawned: bool
    state.drop(spawned)

  tick:
    if pieceDropTicking:
      inc pieceDropTick
      if pieceDropTick * pieceDropTickMultiplier >= adjustFps(pieceDropTime):
        state.tetris.drop()
        pieceDropTick = 0
      for r in 0..<Rows:
        var anyEmpty = false
        for c in 0..<Columns:
          if board[coord(c, r)] == tetNone:
            anyEmpty = true
            break
        if not anyEmpty:
          for ri in countdown(r, 0):
            for ci in 0..<Columns:
              if ri == 0:
                board[coord(ci, ri)] = tetNone
              else:
                swap board[coord(ci, ri)], board[coord(ci, ri - 1)]
      var maxRow = 0
      for c in piece.coveredCoords:
        if c.row > maxRow: maxRow = c.row
      if maxRow < VisibleStart:
        state.switch(gsInitial) # lost

  render:
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
    for i, p in nextPieces:
      drawColor pieceColors[p.kind]
      var maxX, maxY = 0
      for c in coveredCoords(p):
        if c.column > maxX: maxX = c.column
        if c.row > maxY: maxY = c.row
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
        let x = cint translateX c.column.float * unit + tileXStart
        let y = cint translateY c.row.float * unit + tileYStart
        fillRect x, y, tileWidth, tileHeight

    # hold pieces:
    drawColor guideColor
    drawRect(
      cint translateX 13 * Div23,
      cint translateY 3 * Div23,
      cint ceil scaleX 5 * Div23,
      cint ceil scaleY 5 * Div23)
    if holdPiece.kind != tetNone:
      const HoldPieceStart = 14 * Div23
      const unavailableHoldPieceColor = color(60, 60, 60, 255)
      drawColor if justHeld: unavailableHoldPieceColor else: pieceColors[holdPiece.kind]
      var maxX, maxY = 0
      for c in coveredCoords(holdPiece):
        if c.column > maxX: maxX = c.column
        if c.row > maxY: maxY = c.row
      const HoldPieceArea = 3 * Div23
      let
        width = maxX + 1
        height = maxY + 1
        unit = HoldPieceArea / max(width, height).float
        tileWidth = cint ceil scaleX unit
        tileHeight = cint ceil scaleY unit
        tileXStart = HoldPieceStart + (HoldPieceArea - width.float * unit) / 2
        tileYStart = 4 * Div23 + (HoldPieceArea - height.float * unit) / 2
      for c in coveredCoords(holdPiece):
        let x = cint translateX c.column.float * unit + tileXStart
        let y = cint translateY c.row.float * unit + tileYStart
        fillRect x, y, tileWidth, tileHeight
    
    # board:
    for rowI in VisibleStart..<Rows:
      for colI in 0..<Columns:
        let p = board[coord(colI, rowI)]
        let x = cint translateX colI * TilePix + ColumnStart
        let y = cint translateY (rowI - VisibleStart) * TilePix
        if p != tetNone:
          drawColor pieceColors[p]
          fillRect x, y, scaledTileWidth, scaledTileHeight
        drawColor guideColor
        drawRect(x, y, scaledTileWidth, scaledTileHeight)
    
    # shadow piece:
    var shadowPiece = piece
    while true:
      let oldPos = shadowPiece.pos
      let newRow = oldPos.row + 1
      if newRow notin Row or (shadowPiece.pos = coord(oldPos.column, newRow); board.overlapsOrOOB(shadowPiece)):
        shadowPiece.pos = oldPos
        break
    const shadowColor = color(200, 200, 200, 255)
    drawColor shadowColor
    for c in coveredCoords(shadowPiece):
      if c.row >= VisibleStart:
        let x = cint translateX c.column * TilePix + ColumnStart
        let y = cint translateY (c.row - VisibleStart) * TilePix
        fillRect x, y, scaledTileWidth, scaledTileHeight
    
    # real piece:
    drawColor pieceColors[piece.kind]
    for c in coveredCoords(piece):
      if c.row >= VisibleStart:
        let x = cint translateX c.column * TilePix + ColumnStart
        let y = cint translateY (c.row - VisibleStart) * TilePix
        fillRect x, y, scaledTileWidth, scaledTileHeight
  
  key:
    caseCOrJs (event.keysym.scancode, $event.key):
    of (SDL_SCANCODE_X, "x"):
      state.tetris.rotate(forward = true)
    of (SDL_SCANCODE_Z, "z"):
      state.tetris.rotate(forward = false)
    of (SDL_SCANCODE_C, "c"):
      if not justHeld:
        justHeld = true
        let oldHoldPiece =
          if holdPiece.kind != tetNone:
            holdPiece
          else:
            state.tetris.nextPiece()
        holdPiece = piece
        var
          minX = holdPiece.pos.column
          minY = holdPiece.pos.row
        for c in coveredCoords(holdPiece):
          if c.column < minX: minX = c.column
          if c.row < minY: minY = c.row
        holdPiece.pos = coord(holdPiece.pos.column - minX, holdPiece.pos.row - minY)
        state.tetris.spawnPiece(oldHoldPiece)
    of (SDL_SCANCODE_DOWN, "ArrowDown"), (_, "Down"):
      pieceDropTime = 10
      pieceDropRetries = 3
    of (SDL_SCANCODE_UP, "ArrowUp"), (_, "Up"):
      pieceDropRetry = pieceDropRetries
      var spawned: bool
      while not spawned: state.tetris.drop(spawned)
      pieceDropTick = 0
    of (SDL_SCANCODE_D, "d"):
      inc pieceDropTickMultiplier
    of (SDL_SCANCODE_S, "s"):
      pieceDropTickMultiplier = max(0, pieceDropTickMultiplier - 1)
    of (SDL_SCANCODE_I, "i"), (_, "ı"):
      setVolume(max(0, musicVolume - 16))
    of (SDL_SCANCODE_O, "o"):
      setVolume(min(128, musicVolume + 16))
    of (SDL_SCANCODE_ESCAPE, "Escape"):
      state.switch(gsInitial)
    else: discard
  
  keyRepeat:
    caseCOrJs (event.keysym.scancode, $event.key):
    of (SDL_SCANCODE_LEFT, "ArrowLeft"), (_, "Left"):
      var minCol = high Column
      for c in piece.coveredCoords:
        if c.column < minCol: minCol = c.column
      if minCol != low Column:
        var newPiece = piece
        newPiece.pos = Coord(newPiece.pos.int - 1)
        if not board.overlaps(newPiece):
          piece = newPiece
    of (SDL_SCANCODE_RIGHT, "ArrowRight"), (_, "Right"):
      var maxCol = 0
      for c in piece.coveredCoords:
        if c.column > maxCol: maxCol = c.column
      if maxCol != high Column:
        var newPiece = piece
        newPiece.pos = Coord(newPiece.pos.int + 1)
        if not board.overlaps(newPiece):
          piece = newPiece
    else: discard
  
  keyReleased:
    caseCOrJs (event.keysym.scancode, $event.key):
    of (SDL_SCANCODE_DOWN, "ArrowDown"), (_, "Down"):
      pieceDropTime = 120
      pieceDropRetries = 1
    else: discard
  
  when false:
    windowResize:
      let (width, height) = window.getSize
      let a = width / ReferenceWidth
      let b = height / ReferenceHeight
      if a != b:
        let min = min(a, b)
        window.setSize cint round min * ReferenceWidth, cint round min * ReferenceHeight
