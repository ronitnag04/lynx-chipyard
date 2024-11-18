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

# create dts to checkpoint with in spike
pushd sims/vcs
make CONFIG=dmiCheckpointingRocketConfig verilog
CHECKPOINT_DTS=$CY_DIR/sims/vcs/generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig.dts
popd

# 0x18013 is the instruction "trigger" given in the workload
./scripts/generate-ckpt.sh -v -b $FM_WORKLOAD_OUTPUT -t 0x18013 -s $CHECKPOINT_DTS -g $FM_WORKLOAD_OUTPUT_IMG
LOADARCH_PATH=$CY_DIR/${WORKLOAD}-bin.0x80000000.0x18013.0.customdts.loadarch

# make sure you can boot into it in target SW RTL simulation
pushd sims/vcs
cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_dtm.h generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_dtm.h
cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_dtm.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_dtm.cc
# cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_tsi.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_tsi.cc
# cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/testchip_tsi.h generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/testchip_tsi.h
# cp $CY_DIR/generators/testchipip/src/main/resources/testchipip/csrc/SimTSI.cc generated-src/chipyard.harness.TestHarness.dmiCheckpointingRocketConfig/gen-collateral/SimTSI.cc
make CONFIG=dmiCheckpointingRocketConfig run-binary-debug LOADARCH=$LOADARCH_PATH EXTRA_SIM_FLAGS="+blkdev=$FM_WORKLOAD_OUTPUT_IMG" TIMEOUT_CYCLES=100000000
popd

echo "Successful checkpoint!"
