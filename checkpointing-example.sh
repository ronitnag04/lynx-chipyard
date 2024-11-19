#!/bin/bash

set -ex

# assuming you have env.sh sourced

CY_DIR=$(git rev-parse --show-toplevel)
cd $CY_DIR

WORKLOAD_PATH=software/fleetbench/marshal-configs/

WORKLOAD=encrypt-measure
WORKLOAD_SUFFIX=yaml

# need nodisk version
pushd $WORKLOAD_PATH
marshal -v build $WORKLOAD.$WORKLOAD_SUFFIX
popd
FM_WORKLOAD_OUTPUT=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}-bin
FM_WORKLOAD_OUTPUT_IMG=$CY_DIR/software/firemarshal/images/firechip/${WORKLOAD}/${WORKLOAD}.img

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

# 0x18013 is the instruction "trigger" given in the workload
# need to match the dram space of the sim
./scripts/generate-ckpt.sh -v -b $FM_WORKLOAD_OUTPUT -t 0x18013 -s $CHECKPOINT_DTS -g $FM_WORKLOAD_OUTPUT_IMG -r $((0x80000000)):$((0x400000000))
LOADARCH_PATH=$CY_DIR/${WORKLOAD}-bin.0x80000000.0x18013.0.customdts.loadarch

./sparsity-testing-scripts/generate_sparse_elf.sh $LOADARCH_PATH/mem.elf $LOADARCH_PATH/sparse-mem.elf
mv $LOADARCH_PATH/mem.elf $LOADARCH_PATH/old-mem.elf
mv $LOADARCH_PATH/sparse-mem.elf $LOADARCH_PATH/mem.elf

# since it's a NIC-sim you need to use the manager to startup a switch sim
# # make sure you can boot into it in target SW RTL simulation
# pushd sims/firesim
# source sourceme-manager.sh --skip-ssh-setup
# pushd sim
# # cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_dtm.h generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_dtm.h
# # cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_dtm.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_dtm.cc
# # cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_tsi.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_tsi.cc
# # cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_tsi.h generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_tsi.h
# # cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/SimTSI.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/SimTSI.cc
# #make CONFIG=dmiCheckpointingRocketConfig run-binary-debug LOADARCH=$LOADARCH_PATH EXTRA_SIM_FLAGS="+blkdev=$FM_WORKLOAD_OUTPUT_IMG" TIMEOUT_CYCLES=100000000
# make \
#     PLATFORM=xilinx_alveo_u250 \
#     TARGET_PROJECT=firesim \
#     TARGET_PROJECT_MAKEFRAG=$CY_DIR/generators/firechip/chip/src/main/makefrag/firesim \
#     DESIGN=FireSim \
#     TARGET_CONFIG=WithJumboFrames_WithNIC_FireSimHyperscaleTotal8Config \
#     PLATFORM_CONFIG=WithAutoCounter_MTModels_MCRams_FRFCFS16GBQuadRank_BaseXilinxAlveoU250Config \
#     run-vcs
# popd
# popd

echo "Successful checkpoint!"
