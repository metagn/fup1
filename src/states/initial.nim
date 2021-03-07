state Initial:
  let background = loadTexture("assets/mainmenu.png")

  finish: background.destroy()
  
  render:
    draw(background, 0, 0, windowWidth, windowHeight)

  key:
    if not modsHeldDown:
      caseCOrJs (event.keysym.scancode, $event.key):
      of (SDL_SCANCODE_ESCAPE, "Escape"):
        when not defined(js): state.switch(gsDone)
      else:
        state.switch(gsTetris)
