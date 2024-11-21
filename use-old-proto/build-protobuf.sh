#!/usr/bin/env bash

set -ex

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPTDIR

# setup protobuf repo
PROTOBUFREPO=$SCRIPTDIR/protobuf-library-for-accel-ae
pushd $PROTOBUFREPO
git submodule update --init --recursive

# use _build/ since protobuf repo already gitignores it
X86BUILDDIR=$SCRIPTDIR/_build/x86
X86INSTALLDIR=$SCRIPTDIR/_install/x86
rm -rf $X86BUILDDIR
mkdir -p $X86BUILDDIR
rm -rf $X86INSTALLDIR
mkdir -p $X86INSTALLDIR

RISCVBUILDDIR=$SCRIPTDIR/_build/riscv
RISCVINSTALLDIR=$SCRIPTDIR/_install/riscv
rm -rf $RISCVBUILDDIR
mkdir -p $RISCVBUILDDIR
rm -rf $RISCVINSTALLDIR
mkdir -p $RISCVINSTALLDIR

./autogen.sh

cd $X86BUILDDIR
make clean || true
$PROTOBUFREPO/configure --prefix=$X86INSTALLDIR --disable-shared
make -j32
make install

cd $RISCVBUILDDIR
make clean || true
$PROTOBUFREPO/configure --prefix=$RISCVINSTALLDIR --with-protoc=$X86INSTALLDIR/bin/protoc --host=riscv64-unknown-linux-gnu CC=riscv64-unknown-linux-gnu-gcc CXX=riscv64-unknown-linux-gnu-g++ --disable-shared
make -j32
make install
