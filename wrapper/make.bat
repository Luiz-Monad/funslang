REM ghc mandelbrot.c -o mandelbrot.exe ../common/funslang.c ../haskell/*.notprof.o -package containers -package mtl -package fgl -package bytestring -package directory -package process -Wall -Iinclude -I../common -I../haskell -L. -lglew32 -lglut32 -lopengl32 -lglu32
ghc main.c -o main.exe ../common/funslang.c ../haskell/*.notprof.o -package containers -package mtl -package fgl -package bytestring -package directory -package process -Wall -Iinclude -I../common -I../haskell -L. -lglew32 -lglut32 -lopengl32 -lglu32 -I../external/include -L../external/lib -ljpeg -lpng