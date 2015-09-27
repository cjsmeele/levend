# Copyright (c) 2015, Chris Smeele
# All rights reserved.

# Parameters {{{

ifdef VERBOSE
Q :=
E := @true 
else
Q := @
E := @echo 
endif

# }}}
# Package metadata {{{

PACKAGE_NAME := levend

# }}}
# Directories {{{

SRCDIR := src
OBJDIR := obj
BINDIR := bin

# }}}
# Source and intermediate files {{{

DFILES   := $(shell find $(SRCDIR) -name "*.d")
OBJNAMES := $(DFILES:$(SRCDIR)/%.d=%)
OBJFILES := $(OBJNAMES:%=$(OBJDIR)/%.o)
INFILES  := $(DFILES)

# }}}
# Output files {{{

BINFILE  := $(BINDIR)/$(PACKAGE_NAME)
OUTFILES := $(OBJFILES) $(BINFILE)

# }}}
# Toolkit {{{

D  := ldmd2
LD := ldmd2

# }}}
# Toolkit flags {{{

DFLAGS  += -Isrc -Iderelict-sdl2-1.9.7/source -Iderelict-util-2.0.3/source
LDFLAGS += libDerelictSDL2.a libDerelictUtil.a

# }}}

-include Makefile.local

# Make targets {{{

.PHONY: all test clean

# Phony {{{

all: $(BINFILE)

test: $(BINFILE)
	./$(BINFILE)

clean:
	$(Q)rm -rf $(OBJDIR) $(BINDIR)

# }}}
# Output files {{{

$(BINFILE): $(OBJFILES)
	$(E)"  LD  $@"
	$(Q)if [ ! -d `dirname $@` ]; then mkdir -p `dirname $@`; fi
	$(Q)$(LD) $(LDFLAGS) -of$@ $(OBJFILES)

# }}}
# Code compilation {{{

$(OBJDIR)/%.o: $(SRCDIR)/%.d
	$(E)"  D   $<"
	$(Q)if [ ! -d `dirname $@` ]; then mkdir -p `dirname $@`; fi
	$(Q)$(D) -of$@ -c $< $(DFLAGS)

# }}}
# }}}
