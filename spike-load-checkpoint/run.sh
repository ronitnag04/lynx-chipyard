#!/bin/bash

set -ex

# ./spike-main.x86

spike \
	--extlib=libspikedevices.so \
	--device="iceblk,img=/scratch/abejgonza/work/hy-07092024-again/software/firemarshal/images/firechip/encrypt-measure-checkpoint/encrypt-measure-checkpoint.img" \
	-m2147483648:268435456 \
	--dtb=../encrypt-measure-checkpoint-bin.0x80000000.0x18013.0.customdts.loadarch/tmp.dtb \
	--pmpregions=0 \
	--isa=rv64imafdcbzicsr_zifencei_zihpm_zfh_zba_zbb_zbs \
	-p1 \
	/scratch/abejgonza/work/hy-07092024-again/software/firemarshal/images/firechip/encrypt-measure-checkpoint/encrypt-measure-checkpoint-bin
