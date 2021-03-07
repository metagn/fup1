import macros

macro caseCOrJs*(val: untyped, branches: varargs[untyped]): untyped =
  proc transform(n: NimNode): NimNode =
    result = n
    if result.kind in {nnkPar, nnkBracket, nnkCurly}:
      result = result[int defined(js)]
  result = newNimNode(nnkCaseStmt)
  result.add(transform val)
  for b in branches:
    case b.kind
    of nnkOfBranch, nnkElifBranch:
      let newB = newNimNode(b.kind, b)
      let lastIndex = b.len - 1
      for i in 0 ..< lastIndex:
        let elem = transform b[i]
        if not elem.eqIdent"_":
          newB.add(elem)
      newB.add(b[lastIndex])
      result.add(newB)
    else:
      result.add(b)
