if defined(compile32bit):
  --cpu:i386
  --passC:"-m32"
  --passL:"-m32"
  --"gcc.path":getEnv("MINGW_32")
  --outdir:win32
else:
  --outdir:win64
if defined(release):
  --app:gui
  --gc:arc
else:
  --app:console
