#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -ex

DO_CKPT=true
while [ "$1" != "" ];
do
    case $1 in
        -s)
            DO_CKPT=false ;;
    esac
    shift
done

if [ "$DO_CKPT" = true ]; then
TMPDTS=modified.dts
./scripts/generate-ckpt.sh \
    -b ./software/firemarshal/images/firechip/protoacc-des-ubmark/protoacc-des-ubmark-bin-nodisk \
    -t 0x8013 \
    -r $((0x80000000)):$((0x80000000)) \
    -s $TMPDTS -v
fi

CFG_STR=dmiCkptDesProtoConfig
pushd sims/vcs
rm -rf simv*${CFG_STR}*
make \
    CONFIG=${CFG_STR} \
    run-binary-fast \
    timeout_cycles=100000000 \
    LOADARCH=$(readlink -f $SCRIPT_DIR/protoacc-des-ubmark*8013*loadarch)

# other

#cp ../../generators/testchipip/csrc/cospike_impl.cc generated-src/chipyard.harness.TestHarness.dmiProtoConfig/gen-collateral/
#    CONFIG=dmiSpikeUltraFastConfig \
#    #LOADARCH=$(readlink -f $SCRIPT_DIR/protoacc-ser-ubmark-nodisk.*.loadarch) \
#    #
#    #
#    EXTRA_SIM_FLAGS="+spike-verbose" \
    #EXTRA_SIM_FLAGS="+cospike-debug +cospike-printf=1" \
    #EXTRA_SIM_FLAGS="+cospike-enable=0" \

#pushd sims/vcs
#make \
#    CONFIG=dmiProtoConfig \
#    run-binary \
#    timeout_cycles=10000000000 \
#    LOADMEM=1 \
#    BINARY=$SCRIPT_DIR/software/firemarshal/images/firechip/protoacc-ser-bmarks-htif-ubmarks-ser/protoacc-ser-bmarks-htif-ubmarks-ser-bin-nodisk \
