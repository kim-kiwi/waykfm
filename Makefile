ifeq ($(OS),Windows_NT)
    PLATFORM := WINDOWS
else
    PLATFORM := UNIX
endif

ifeq ($(WIN),1)
	CFLAGS=-L./raylib-5.5_win64_mingw-w64/lib -I./raylib-5.5_win64_mingw-w64/include
	CLIBS=-l:libraylib.a -lm -lopengl32 -lgdi32 -lwinmm
	ifeq ($(PLATFORM),WINDOWS)
		CC=gcc
	else
		CC=x86_64-w64-mingw32-gcc
	endif
else
	CFLAGS=-L./raylib-5.5_linux_amd64/lib -I./raylib-5.5_linux_amd64/include
	CLIBS=-l:libraylib.a -lm
	CC=gcc
endif

DIRS:=src src/entities

C_SRC:=$(foreach dir,$(DIRS),$(wildcard $(dir)/*.c))
C_HED:=$(foreach dir,$(DIRS),$(wildcard $(dir)/*.h))

OBJ := $(patsubst src/%.c,bin/%.o,$(C_SRC))
DEPS := $(OBJ:.o=.d)

bin/waykfm: $(OBJ) | bin
	$(CC) $(OBJ) $(CFLAGS) $(CLIBS) -o $@

bin/%.o: src/%.c | bin
	@mkdir -p $(dir $@)
	$(CC) -MMD -MP $(CFLAGS) $(CLIBS) -c $< -o $@

bin:
	mkdir bin

clean:
	rm -r bin

-include $(DEPS)
