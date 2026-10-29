# Benoetigt: ACME 1.01mp, GNU make, optional VICE (x64sc)
.RECIPEPREFIX = >
ACME   ?= C:/Users/martin/programme/acme/Release/ACME.exe
VICE   ?= C:/Users/martin/programme/GTK3VICE-3.10-win64/bin/x64sc.exe
TARGET  = build/roboter.prg
DEPS    = $(wildcard src/*.asm inc/*.inc)

all: $(TARGET)

$(TARGET): $(DEPS)
> mkdir -p build
> $(ACME) -f cbm --cpu 6510 -o $@ src/main.asm

run: $(TARGET)
> $(VICE) -pal -autostart $(TARGET)

clean:
> rm -rf build $(TARGET)

.PHONY: all run clean
