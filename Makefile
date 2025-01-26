.POSIX:
# CC = cproc
CC = gcc -std=c99
CFLAGS = -g -Wall
YFLAGS = -d # -t

PREFIX?=/usr/local
BINDIR?=$(PREFIX)/bin
MANDIR?=$(PREFIX)/share/man

SRC = hoc.y hoc.h code.c init.c math.c symbol.c
OBJS = hoc.o code.o init.o math.o symbol.o

hoc: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o hoc -lm

hoc.o code.o init.o symbol.o: hoc.h

code.o init.o symbol.o: y.tab.h

clean:
	-rm -f $(OBJS) y.tab.[ch]

nuke: clean
	-rm -f hoc

check: hoc
	./runtests.sh

install: hoc
	mkdir -p $(BINDIR) $(MANDIR)/man1
	install -m755 hoc $(BINDIR)/hoc
	install -m644 hoc.1 $(MANDIR)/man1/hoc.1

uninstall:
	rm -f $(BINDIR)/hoc
	rm -f $(MANDIR)/man1/hoc.1

.PHONY: clean nuke check install uninstall
