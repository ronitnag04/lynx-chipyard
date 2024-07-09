#!/bin/bash

set -ex

RDIR=$(git rev-parse --show-toplevel)

# move to top-level
cd $RDIR

# rebuild/install fesvr (only necessary if modifications to it have been made)
#./scripts/build-toolchain-extra.sh riscv-tools -p $CONDA_PREFIX/riscv-tools

SND_BIN=smartnic

pushd tests
make clean
# make sure appsoc/smartnic are in tests
make
# should create 2 files - appsoc.riscv smartnic.riscv
./build-for-smartnic.sh ${SND_BIN}
popd

SOC1_BIN=$PWD/tests/appsoc.riscv
#SOC1_BIN=$PWD/tests/nic-loopback.riscv
SOC2_BIN=$PWD/tests/${SND_BIN}.smartnic.riscv

CFG=MinimalIntegrationConfig

pushd sims/vcs
rm -rf uartpty*
rm -rf ${CFG}.out*
#make clean
# payload should load the 2nd binary (provided it has the right addresses)
make CONFIG=${CFG} \
    BINARY=${SOC1_BIN} \
    EXTRA_SIM_FLAGS="+use-loadmem-hack +write-soc1-msip +uartlog=${CFG}.out +payload=${SOC2_BIN} +link_lat_a2s=10 +link_lat_s2a=10" \
    run-binary-debug
rm -rf uartpty*
