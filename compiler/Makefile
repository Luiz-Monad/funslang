GHCFLAGS=-Wall
ALEX=../../tools/alex/alex
HAPPY=../../tools/happy/happy

.PHONY: clean install

all: Parser.hs Lexer.hs lib standalone test

lib: *.hs
	-mkdir bin\notprof
	ghc $(GHCFLAGS) -odir bin/notprof -hidir bin/notprof -c --make LibFunslang
	ghc $(GHCFLAGS) -odir bin/notprof -c *.c -I../common/include -Iinclude
	ghc $(GHCFLAGS) -static -shared -o bin/funslang.dll funslang.def bin/notprof/*.o -package containers -package mtl -package fgl -package bytestring -package directory -package process -lopengl32 -Llib -ljpeg -L../common/bin -lglew32 -lglut32
	-del /Q bin\funslang.dll.a
	lib /machine:i386 /def:funslang.def /out:bin\funslang.lib

standalone: *.hs
	-mkdir bin\prof
	ghc $(GHCFLAGS) -o bin/Main.exe -odir bin/prof -hidir bin/prof -prof -auto-all --make Main

test: bin/Main.exe
	bin/Main -t

Parser.hs: Parser.y
	$(HAPPY) -g -c -i Parser.y

Lexer.hs: Lexer.x
	$(ALEX) -g Lexer.x

clean:
	-del /Q bin\notprof\*.* bin\prof\*.* bin\*.* Parser.hs Lexer.hs

install:
	-mkdir ..\common\lib
	copy /Y bin\funslang.dll ..\common\bin\funslang.dll
	copy /Y bin\funslang.lib ..\common\lib\funslang.lib
