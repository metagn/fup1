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

    piece: Piece

    pieceDropTicking = true
    pieceDropTick = 0
    pieceDropTime = 120

  proc spawnPiece(state: Tetris) {.member.} =
    let nextKind = rand(tetI..tetT)
    piece = Piece(pos: coord(Columns div 2, if nextKind in {tetJ, tetL}: VisibleStart + 1 else: VisibleStart), rot: 0, kind: nextKind)
    while board.overlaps(piece):
      piece.pos = Coord(piece.pos.int - Columns)

  init:
    randomize()
    state.tetris.spawnPiece()
    setMusic(currentMusic, "assets/music.ogg")
    loopMusic(currentMusic)
  
  finish: stopMusic(currentMusic)
  
  proc overlaps(board: array[Coord, PieceKind], piece: Piece): bool =
    result = false
    for c in piece.coveredCoords:
      if board[c] != tetNone:
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
    if outOfBounds:
      outOfBounds = false
      # check left first
      let (col0, row0) = (newPiece.pos.column, newPiece.pos.row)
      if col0 - 1 in Column:
        newPiece.pos = coord(col0 - 1, row0)
        for _ in newPiece.coveredCoords(outOfBounds): discard
      else: outOfBounds = true
      if outOfBounds:
        outOfBounds = false
        # check right second
        if col0 + 1 in Column:
          newPiece.pos = coord(col0 + 1, row0)
          for _ in newPiece.coveredCoords(outOfBounds): discard
        else: outOfBounds = true
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
      if pieceDropTick >= pieceDropTime:
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
    let relativeTilePix = cint round TilePix * windowWidth / ReferenceWidth
    for rowI in VisibleStart..<Rows:
      for colI in 0..<Columns:
        let p = board[coord(colI, rowI)]
        let screenX = cint (colI * TilePix + ColumnStart) * windowWidth / ReferenceWidth
        let screenY = cint ((rowI - VisibleStart) * TilePix) * windowHeight / ReferenceHeight
        if p != tetNone:
          drawColor pieceColors[p]
          fillRect screenX, screenY, relativeTilePix, relativeTilePix
        drawColor 80, 80, 80
        renderer.drawRect((var r = rect(screenX, screenY, relativeTilePix, relativeTilePix); addr r))
    drawColor pieceColors[piece.kind]
    for c in coveredCoords(piece):
      if c.row >= VisibleStart:
        let screenX = cint (c.column * TilePix + ColumnStart) * windowWidth / ReferenceWidth
        let screenY = cint ((c.row - VisibleStart) * TilePix) * windowHeight / ReferenceHeight
        drawColor pieceColors[piece.kind]
        fillRect screenX, screenY, relativeTilePix, relativeTilePix
  
  key:
    case event.keysym.scancode
    of SDL_SCANCODE_X:
      state.tetris.rotate(forward = true)
    of SDL_SCANCODE_Z:
      state.tetris.rotate(forward = false)
    of SDL_SCANCODE_DOWN:
      pieceDropTime = 10
    of SDL_SCANCODE_UP:
      var spawned: bool
      while not spawned: state.tetris.drop(spawned)
      pieceDropTick = 0
    of SDL_SCANCODE_ESCAPE:
      state.switch(gsInitial)
    else: discard
  
  keyRepeat:
    case event.keysym.scancode
    of SDL_SCANCODE_LEFT:
      var minCol = high Column
      for c in piece.coveredCoords:
        if c.column < minCol: minCol = c.column
      if minCol != low Column:
        var newPiece = piece
        newPiece.pos = Coord(newPiece.pos.int - 1)
        if not board.overlaps(newPiece):
          piece = newPiece
    of SDL_SCANCODE_RIGHT:
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
    case event.keysym.scancode
    of SDL_SCANCODE_DOWN:
      pieceDropTime = 120
    else: discard
