PROTODIR=/scratch/junsun/hyperscale-grpc-chipyard/generators/protoacc/microbenchmarks
PROTOX86INSTALLDIR=$PROTODIR/protobuf-x86-install
PROTORISCVINSTALLDIR=$PROTODIR/protobuf-riscv-install
rm libproto.so
g++ -L $RISCV/lib -Wl,-rpath,$RISCV/lib -shared -o libproto.so -std=c++17 -I $RISCV/include -I $PROTOX86INSTALLDIR/include -fPIC -O3 proto.cc
cp libproto.so $RISCV/lib
riscv64-unknown-linux-gnu-g++ -std=c++11 -O3 -g3 -static -D NDEBUG proto_test.cpp primitives_des.pb.cc accellib.cpp -I $PROTORISCVINSTALLDIR/include -pthread $PROTORISCVINSTALLDIR/lib/libprotobuf.a -o a.out
spike --extension=proto pk a.out
