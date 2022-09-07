import common

type Initial* = ref object
  background*: TexturePtr

template init*(state: var Initial, global: Global) =
  state = Initial()
  state.background = loadTexture("assets/mainmenu.png")

template finish*(state: Initial, global: Global) =
  state.background.destroy()

template render*(state: Initial, global: Global, windowWidth, windowHeight: cint) =
  state.background.draw(0, 0, windowWidth, windowHeight)

template key*(state: Initial, global: Global, event: KeyboardEventPtr) =
  if not modsHeldDown():
    caseCOrJs (event.keysym.scancode, $event.key):
    of (SDL_SCANCODE_ESCAPE, "Escape"):
      when not defined(js): game.switch(gsDone)
    else:
      game.switch(gsTetris)
