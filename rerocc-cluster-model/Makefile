ifndef RISCV
$(error RISCV is unset)
else
$(info Running with RISCV=$(RISCV))
endif

PREFIX ?= $(RISCV)/
EXTENSION_NAME ?= rerocccluster
SO := lib$(EXTENSION_NAME).so

CURRENT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
SNAPPY_COMP_BIN := $(CURRENT_DIR)/../generators/compress-acc/software-snappy/snappy/build-writecomp/snappy_test_tool
SNAPPY_DECOMP_BIN := $(CURRENT_DIR)/../generators/compress-acc/software-snappy/snappy/build-writedecomp/snappy_test_tool

default: $(SO)

$(SO): rerocc_cluster.cc
	g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o $@ -std=c++20 -I $(RISCV)/include -fPIC -O3 \
		-DEXTENSION_NAME=$(EXTENSION_NAME) \
		-DCUR_DIR=$(CURRENT_DIR) \
		-DSNAPPY_COMP_BIN=$(SNAPPY_COMP_BIN) \
		-DSNAPPY_DECOMP_BIN=$(SNAPPY_DECOMP_BIN) \
		$^

.PHONY: install
install: $(SO)
	cp $(SO) $(RISCV)/lib

clean:
	rm -rf *.o $(SO)
