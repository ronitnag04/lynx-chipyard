ifndef RISCV
$(error RISCV is unset)
else
$(info Running with RISCV=$(RISCV))
endif

PREFIX ?= $RISCV/

default: libmemcpy.so

libmemcpy.so: memcpy.cc
	g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $^

.PHONY: install
install: libmemcpy.so
	cp libmemcpy.so $(RISCV)/lib

clean:
	rm -rf *.o *.so
