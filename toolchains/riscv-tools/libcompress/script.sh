rm libproto.so
g++ -L $(RISCV)/lib -Wl,-rpath,$(RISCV)/lib -shared -o libproto.so -std=c++17 -I $(RISCV)/include -fPIC -O3 proto.cc
cp libproto.so $RISCV/lib
riscv-unknown-elf-gcc proto_test.c
spike --extension=proto pk a.out
