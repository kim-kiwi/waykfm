CFLAGS=-L.\raylib-5.5_win64_mingw-w64\lib -I.\raylib-5.5_win64_mingw-w64\include -l:libraylib.a -lm -lopengl32 -lgdi32 -lwinmm

CC=gcc

DIRS:=src src/entities

C_SRC:=$(foreach dir,$(DIRS),$(wildcard $(dir)/*.c))
C_HED:=$(foreach dir,$(DIRS),$(wildcard $(dir)/*.h))

bin/main: $(C_SRC) $(C_HED) bin
	$(CC) -o bin/main $(C_SRC) $(CFLAGS) -O2

bin:
	mkdir bin
