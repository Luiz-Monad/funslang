ghc mandelbrot.c ../common/funslang.c ../haskell/*.notprof.o -package containers -package mtl -package fgl -package bytestring -package directory -package process -Wall -Iinclude -I../common -I../haskell -L. -lglew32 -lglut32 -lopengl32 -lglu32
