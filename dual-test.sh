#!/bin/bash

set -ex

# have to rebuild/install fesvr
./scripts/build-toolchain-extra.sh riscv-tools -p $CONDA_PREFIX/riscv-tools

pushd tests
make clean
# make sure appsoc/smartnic are in tests
make
# should create 2 files - appsoc.riscv smartnic.riscv
./build-for-smartnic.sh smartnic
popd

SOC2_BIN=$PWD/tests/smartnic.smartnic.riscv

pushd sims/vcs
rm -rf uartpty*
make clean
# payload should load the 2nd binary (provided it has the right addresses)
make CONFIG=IntegrationConfig2 \
    BINARY=../../tests/appsoc.riscv \
    EXTRA_SIM_FLAGS="+payload=${SOC2_BIN}" \
    run-binary
