# fup1

Productivity experiment on writing Tetris using Nim macros. Implemented for both SDL and JS canvas (which the metaprogramming for was actually very simple).

Windows binaries in releases, browser version at https://hlaaftana.github.io/fup1/browser.

No score system or comprehensive interface, no sophisticated T-spins, I and O piece rotations are different.

While I generally feel like this was a success, the overarching macro could use improvements on implementation as well as design. Being closer to bare Nim while keeping a unique structure seems to be the play.

Unfortunately I attempted to write a more comprehensive game project in these macros before this, when I should have made sure that I had a good framework. Don't know if I'm going to reach a spot where macros can't help anymore and the language has to be different (i.e. with scripting. No language comes close to Nim otherwise).
