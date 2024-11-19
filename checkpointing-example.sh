#!/bin/bash

set -ex

# assuming you have env.sh sourced

CY_DIR=$(git rev-parse --show-toplevel)
cd $CY_DIR

WORKLOAD_PATH=software/fleetbench/marshal-configs/

WORKLOAD=encrypt-measure
WORKLOAD_SUFFIX=yaml

INST_HEX=18013
# 0x18013 is the instruction "trigger" given in the workload

# need nodisk version
pushd $WORKLOAD_PATH
marshal -v build $WORKLOAD.$WORKLOAD_SUFFIX
popd
FM_WORKLOAD_OUTPUT=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}-bin
FM_WORKLOAD_OUTPUT_IMG=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}.img
riscv64-unknown-elf-objdump -S $CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}-bin-dwarf > ${WORKLOAD}.dump
grep "$INST_HEX " ${WORKLOAD}.dump

## optional: verify it boots with spike (spike will use it's own uart for output)
#spike --pc=0x80000000 $FM_WORKLOAD_OUTPUT

MODEL_PACKAGE_VAR=firechip.chip
MODEL_VAR=FireSim
#CONFIG_VAR=WithJumboFrames_WithNIC_DTMFireSimHyperscaleTotal8Config
CONFIG_VAR=DTMFireSimHyperscaleTotal1Config
LONG_NAME=${MODEL_PACKAGE_VAR}.${MODEL_VAR}.${CONFIG_VAR}
# create dts to checkpoint with in spike
pushd sims/firesim-staging
make \
    SBT_PROJECT=firechip \
    MODEL=${MODEL_VAR} \
    MODEL_PACKAGE=${MODEL_PACKAGE_VAR} \
    VLOG_MODEL=FireSim \
    CONFIG=${CONFIG_VAR} \
    CONFIG_PACKAGE=firechip.chip \
    GENERATOR_PACKAGE=chipyard \
    EXTRA_CHISEL_OPTIONS=--emit-legacy-sfc \
    TB=unused \
    TOP=unused
CHECKPOINT_DTS=$CY_DIR/sims/firesim-staging/generated-src/${LONG_NAME}/${LONG_NAME}.dts
popd

# need to match the dram space of the sim
./scripts/generate-ckpt.sh -v -b $FM_WORKLOAD_OUTPUT -t 0x${INST_HEX} -s $CHECKPOINT_DTS -g $FM_WORKLOAD_OUTPUT_IMG -r $((0x80000000)):$((0x400000000))
LOADARCH_PATH=$CY_DIR/${WORKLOAD}-bin.0x80000000.0x${INST_HEX}.0.customdts.loadarch

./sparsity-testing-scripts/generate_sparse_elf.sh $LOADARCH_PATH/mem.elf $LOADARCH_PATH/sparse-mem.elf
mv $LOADARCH_PATH/mem.elf $LOADARCH_PATH/old-mem.elf
mv $LOADARCH_PATH/sparse-mem.elf $LOADARCH_PATH/mem.elf

echo "Successful checkpoint!"
