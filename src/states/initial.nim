state Initial:
  let background = renderer.loadTexture("assets/mainmenu.png")

  finish: background.destroy()
  
  render:
    renderer.draw(background, rect(0, 0, windowWidth, windowHeight))

  key:
    if not modsHeldDown:
      case event.keysym.scancode
      of SDL_SCANCODE_ESCAPE:
        state.switch(gsDone)
      else:
        state.switch(gsTetris)