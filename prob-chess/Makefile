CC      ?= gcc
CFLAGS  ?= -O3 -std=gnu11 -Wall -Wextra -Wno-unused-parameter -march=native -flto
LDFLAGS ?= -lm -flto
SRC     := src/board.c src/eval.c src/search.c src/persona.c src/main.c
OBJ     := $(SRC:.c=.o)
BIN     := belief

all: $(BIN)

$(BIN): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ) $(LDFLAGS)

%.o: %.c src/core.h
	$(CC) $(CFLAGS) -Isrc -c $< -o $@

test: $(BIN)
	./tests/run_perft.sh
	./tests/run_tactics.sh 3
	./$(BIN) personas | tail -1

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean test
