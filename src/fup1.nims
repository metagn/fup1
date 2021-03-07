if defined(compile32bit):
  --cpu:i386
  --passC:"-m32"
  --passL:"-m32"
  switch("gcc.path", getEnv("MINGW_32"))
  --outdir:win32
elif defined(windows):
  --outdir:win64
if defined(release):
  --app:gui
  --gc:arc
else:
  --app:console
