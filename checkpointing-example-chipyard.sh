#!/bin/bash

set -ex

# assuming you have env.sh sourced

CY_DIR=$(git rev-parse --show-toplevel)
cd $CY_DIR

WORKLOAD_PATH=software/fleetbench/marshal-configs/

WORKLOAD=encrypt-measure
WORKLOAD_SUFFIX=yaml

# need nodisk version to checkpoint into userspace
pushd $WORKLOAD_PATH
marshal -v build $WORKLOAD.$WORKLOAD_SUFFIX
popd
FM_POSTFIX=-bin
FM_WORKLOAD_OUTPUT=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}${FM_POSTFIX}
FM_WORKLOAD_OUTPUT_IMG=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}.img

CONFIG_VAR=DTMHyperscaleTotal1Config
LONG_NAME=chipyard.harness.TestHarness.${CONFIG_VAR}
NOACC_LONG_NAME=chipyard.harness.TestHarness.${CONFIG_VAR}
# create dts to checkpoint with in spike
pushd sims/vcs
make CONFIG=${CONFIG_VAR} verilog
CHECKPOINT_DTS=$CY_DIR/sims/vcs/generated-src/${NOACC_LONG_NAME}/${NOACC_LONG_NAME}.dts
popd

MEM=0x10000000
#INST=0x18013
INST=0x18013
# 0x18013 is the instruction "trigger" given in the workload
# need to match the dram space of the sim
./scripts/generate-ckpt.sh -v -b $FM_WORKLOAD_OUTPUT -t ${INST} -s $CHECKPOINT_DTS -r $((0x80000000)):$(($MEM)) -g $FM_WORKLOAD_OUTPUT_IMG
LOADARCH_PATH=$CY_DIR/${WORKLOAD}${FM_POSTFIX}.0x80000000.${INST}.0.customdts.loadarch

# # TODO: need to update the linker script with size
# ./sparsity-testing-scripts/generate_sparse_elf.sh $LOADARCH_PATH/mem.elf $LOADARCH_PATH/sparse-mem.elf
# mv $LOADARCH_PATH/mem.elf $LOADARCH_PATH/old-mem.elf
# mv $LOADARCH_PATH/sparse-mem.elf $LOADARCH_PATH/mem.elf
exit 11

pushd sims/vcs
make CONFIG=${CONFIG_VAR} run-binary LOADARCH=$LOADARCH_PATH TIMEOUT_CYCLES=1000000000 EXTRA_SIM_FLAGS="+blkdev=$FM_WORKLOAD_OUTPUT"
popd

echo "Successful checkpoint!"
