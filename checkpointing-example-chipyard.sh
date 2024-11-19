#!/bin/bash

set -ex

# assuming you have env.sh sourced

CY_DIR=$(git rev-parse --show-toplevel)
cd $CY_DIR

WORKLOAD_PATH=software/fleetbench/marshal-configs/

WORKLOAD=model-measure
SUB_WORKLOAD=proto-compress-protoaccel
WORKLOAD_SUFFIX=yaml

# need nodisk version to checkpoint into userspace
pushd $WORKLOAD_PATH
marshal -v -d build $WORKLOAD.$WORKLOAD_SUFFIX
popd
FM_WORKLOAD_OUTPUT=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}-${SUB_WORKLOAD}/${WORKLOAD}-${SUB_WORKLOAD}-bin-nodisk

CONFIG_VAR=DTMHyperscaleTotal1Config
LONG_NAME=chipyard.harness.TestHarness.${CONFIG_VAR}
NOACC_LONG_NAME=chipyard.harness.TestHarness.${CONFIG_VAR}
# create dts to checkpoint with in spike
pushd sims/vcs
make CONFIG=${CONFIG_VAR} verilog
CHECKPOINT_DTS=$CY_DIR/sims/vcs/generated-src/${NOACC_LONG_NAME}/${NOACC_LONG_NAME}.dts
popd

INST=0x28013
# 0x18013 is the instruction "trigger" given in the workload
# need to match the dram space of the sim
./scripts/generate-ckpt.sh -v -b $FM_WORKLOAD_OUTPUT -t ${INST} -s $CHECKPOINT_DTS -r $((0x80000000)):$((0x40000000))
LOADARCH_PATH=$CY_DIR/${WORKLOAD}-${SUB_WORKLOAD}-bin-nodisk.0x80000000.${INST}.0.customdts.loadarch

# ./sparsity-testing-scripts/generate_sparse_elf.sh $LOADARCH_PATH/mem.elf $LOADARCH_PATH/sparse-mem.elf
# mv $LOADARCH_PATH/mem.elf $LOADARCH_PATH/old-mem.elf
# mv $LOADARCH_PATH/sparse-mem.elf $LOADARCH_PATH/mem.elf

pushd sims/vcs
make CONFIG=${CONFIG_VAR} run-binary-debug LOADARCH=$LOADARCH_PATH TIMEOUT_CYCLES=1000000000
popd

echo "Successful checkpoint!"
