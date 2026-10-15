# Builds the compiled-in meme unit. oxinit links the static archive.
CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -Werror -fPIC

all: libmemeunit.a libmemeunit.so

libmemeunit.a: memeunit.o
	ar rcs $@ $<

memeunit.o: memeunit.c
	$(CC) $(CFLAGS) -c -o $@ $<

libmemeunit.so: memeunit.c
	$(CC) $(CFLAGS) -shared -o $@ $<

clean:
	rm -f libmemeunit.a libmemeunit.so memeunit.o

.PHONY: all clean
