# Builds libmemeunit.so, the compiled-in meme unit loaded by oxinit.py.
CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -Werror -fPIC

libmemeunit.so: memeunit.c
	$(CC) $(CFLAGS) -shared -o $@ $<

clean:
	rm -f libmemeunit.so

.PHONY: clean
