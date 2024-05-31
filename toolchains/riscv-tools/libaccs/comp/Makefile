ifndef RISCV
$(error RISCV is unset)
else
$(info Running with RISCV=$(RISCV))
endif

CURRENT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ZSTD_BIN := $(CURRENT_DIR)/zstd

default: libcomp.so

libcomp.so: comp.cc
	g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -DCUR_DIR=$(CURRENT_DIR) -DZSTD_BIN=$(ZSTD_BIN) -fPIC -O3 $^

.PHONY: install
install: libcomp.so
	cp libcomp.so $(RISCV)/lib

clean:
	rm -rf *.o *.so
