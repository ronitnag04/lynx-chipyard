#################################
# RISCV Toolchain
#################################

TARGET = riscv64-unknown-elf

GCC = $(TARGET)-gcc
CXX = $(TARGET)-g++
CP = $(TARGET)-objcopy
OBJDUMP = $(TARGET)-objdump
DG = $(TARGET)-gdb
SIZE = $(TARGET)-size


#################################
# Flags
#################################

# SoC Settings
ARCH = rv64imafdc
ABI = lp64d
ARCHFLAGS = -march=$(ARCH) -mabi=$(ABI)

CFLAGS  = -std=gnu99 -O2 -fno-common -fno-builtin-printf -Wall -g
CFLAGS += $(ARCHFLAGS)
CFLAGS += -specs=htif_nano.specs
LDFLAGS = -static

PROGRAMS = comp_test decomp_test

.DEFAULT_GOAL := default


#################################
# Build
#################################

%.riscv: %.c rocc.h encoding.h benchmark_data_0.h accellib.h accellib.c
	$(GCC) $(CFLAGS) $(LDFLAGS) -I$(PWD) accellib.c $< -o $@

%.dump: %.riscv
	$(OBJDUMP) -D -S $< > $@


#################################
# Recipes
#################################

.PHONY: clean
clean:
	rm -f *.riscv *.o *.dump

.PHONY: default
default: $(addsuffix .riscv, $(PROGRAMS))

.PHONY: dumps
dumps: $(addsuffix .dump, $(PROGRAMS))
