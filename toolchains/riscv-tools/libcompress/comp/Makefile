ifndef RISCV
$(error RISCV is unset)
else
$(info Running with RISCV=$(RISCV))
endif

PREFIX ?= $RISCV/

default: libcomp.so

libcomp.so: comp.cc 
	g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++17 -I $(RISCV)/include -fPIC -O3 $^


.PHONY: install
install: libcomp.so
	cp libcomp.so $(RISCV)/lib

clean:
	rm -rf *.o *.so
