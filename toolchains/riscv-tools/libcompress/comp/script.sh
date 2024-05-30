rm a.out
make clean
make
make install
cd decomp
riscv64-unknown-elf-gcc decomp_test.c
spike --extension=comp pk a.out
