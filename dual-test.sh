#!/bin/bash

set -ex

RDIR=$(git rev-parse --show-toplevel)

# move to top-level
cd $RDIR

# rebuild/install fesvr (only necessary if modifications to it have been made)
#./scripts/build-toolchain-extra.sh riscv-tools -p $CONDA_PREFIX/riscv-tools

pushd tests
make clean
# make sure appsoc/smartnic are in tests
make
# should create 2 files - appsoc.riscv smartnic.riscv
./build-for-smartnic.sh smartnic
popd

SOC1_BIN=$PWD/tests/appsoc.riscv
#SOC1_BIN=$PWD/tests/nic-loopback.riscv
SOC2_BIN=$PWD/tests/smartnic.smartnic.riscv

pushd sims/vcs
rm -rf uartpty*
rm -rf IntegrationConfig.out*
#make clean
# payload should load the 2nd binary (provided it has the right addresses)
make CONFIG=IntegrationConfig \
    BINARY=${SOC1_BIN} \
    EXTRA_SIM_FLAGS="+write-soc1-msip +uartlog=IntegrationConfig.out +payload=${SOC2_BIN} +link_lat_a2s=10 +link_lat_s2a=10" \
    run-binary-debug
rm -rf uartpty*
