.PHONY: all
all: $(rvtests) $(x86tests)

%.pb.cc %.pb.h: %.proto
	$(PROTOC) --proto_path=$(@D) --cpp_out=. $<

.PRECIOUS: %.pb.cc %.pb.h

%.riscv: export PKG_CONFIG_PATH := $(RISCVINSTALLDIR)/lib/pkgconfig
%.riscv: %.cpp $(protos)
	$(RVCPP) \
		$(CPPFLAGS) \
		-o $@ \
		-I$(CURRENT_DIR)/../software/sharedapi \
		$< \
		$(protocc) \
		`pkg-config --cflags --libs protobuf`
	$(RVOBJDUMP) -S $@ > $@.dump
	$(RVSTRIP) $@

# note: pkg-config should be at the end
%.x86: export PKG_CONFIG_PATH := $(X86INSTALLDIR)/lib/pkgconfig
%.x86: %.cpp $(protos)
	$(X86C) $(CFLAGS) \
		-c $(CURRENT_DIR)/../software/sharedapi/descriptor_printer.c
	$(X86CPP) \
		$(CPPFLAGS) \
		-o $@ \
		-I$(CURRENT_DIR)/../software/sharedapi \
		$(CURRENT_DIR)/descriptor_printer.o \
		$< \
		$(protocc) \
		`pkg-config --cflags --libs protobuf`
	$(X86STRIP) $@

.PHONY: check-pkgconfig-riscv
check-pkgconfig-riscv: export PKG_CONFIG_PATH := $(RISCVINSTALLDIR)/lib/pkgconfig
check-pkgconfig-riscv:
	echo `pkg-config --cflags --libs protobuf`

.PHONY: check-pkgconfig-x86
check-pkgconfig-x86: export PKG_CONFIG_PATH := $(X86INSTALLDIR)/lib/pkgconfig
check-pkgconfig-x86:
	echo `pkg-config --cflags --libs protobuf`

.PHONY: clean
clean:
	rm -rf *.riscv *.x86 *.pb.cc *.pb.h
