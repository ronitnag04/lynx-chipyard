package chipyard

import org.chipsalliance.cde.config.{Config}
import freechips.rocketchip.subsystem._

// --------------------------------------------------------------------------------------
// Rocket Configs
// --------------------------------------------------------------------------------------

class HyperscaleRocketBaseConfig extends Config(

  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=2048) ++
  new freechips.rocketchip.subsystem.WithNBanks(8) ++
  new chipyard.config.WithExtMemIdBits(7) ++
  new freechips.rocketchip.subsystem.WithNMemoryChannels(4) ++
  new chipyard.config.WithSystemBusWidth(256) ++
  new RocketConfig)

class HyperscaleRocketBaseConfig16MBL2 extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=16*1024) ++
  new HyperscaleRocketBaseConfig)

class HyperscaleRocketBaseConfig16MBL2And8MemChan extends Config(
  new freechips.rocketchip.subsystem.WithNMemoryChannels(8) ++
  new HyperscaleRocketBaseConfig16MBL2)

class HyperscaleRocketBaseConfig32MBL2 extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=32*1024) ++
  new HyperscaleRocketBaseConfig)

class HyperscaleRocketBaseConfig32MBL2And8MemChan extends Config(
  new freechips.rocketchip.subsystem.WithNMemoryChannels(8) ++
  new HyperscaleRocketBaseConfig32MBL2)

class HyperscaleRocketBaseConfig64MBL2 extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=64*1024) ++
  new HyperscaleRocketBaseConfig)

class HyperscaleRocketBaseConfig64MBL2And8MemChan extends Config(
  new freechips.rocketchip.subsystem.WithNMemoryChannels(8) ++
  new HyperscaleRocketBaseConfig64MBL2)

// compress-acc rocket configs
class SnappyDecompressorHyperscaleRocketConfig extends Config(
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig)

class SnappyDecompressorHyperscaleRocketConfig16MBL2 extends Config(
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig16MBL2)

class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChan extends Config(
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChan extends Config(
  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanRoCC extends Config(
  new compressacc.AcceleratorPlacementRoCC ++
  new compressacc.WithSnappyCompleteFireSim ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
  new compressacc.AcceleratorPlacementPCIeNoCache ++
  new compressacc.WithSnappyCompleteFireSim ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
  new compressacc.AcceleratorPlacementPCIeLocalCache ++
  new compressacc.WithSnappyCompleteFireSim ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanChiplet extends Config(
  new compressacc.AcceleratorPlacementChiplet ++
  new compressacc.WithSnappyCompleteFireSim ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
  new compressacc.AcceleratorPlacementPCIeNoCache ++
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
  new compressacc.AcceleratorPlacementPCIeNoCache ++
  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
  new compressacc.AcceleratorPlacementPCIeLocalCache ++
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
  new compressacc.AcceleratorPlacementPCIeLocalCache ++
  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
  new HyperscaleRocketBaseConfig16MBL2And8MemChan)

class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPrintf extends Config(
  new compressacc.WithCompressAccelPrintf ++
  new SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChan)

class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPrintf extends Config(
  new compressacc.WithCompressAccelPrintf ++
  new SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChan)

// --------------------------------------------------------------------------------------
// BOOM Configs
// --------------------------------------------------------------------------------------

// base hyperscale soc megaboom config without any accels
class HyperscaleMegaBoomBaseConfig extends Config(
  //new chipyard.iobinders.WithTiedOffDebug ++
  //new testchipip.WithTSI ++
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=2048) ++
  new freechips.rocketchip.subsystem.WithNBanks(8) ++
  new chipyard.config.WithExtMemIdBits(7) ++
  new freechips.rocketchip.subsystem.WithNMemoryChannels(4) ++
  new chipyard.config.WithSystemBusWidth(256) ++
  new boom.common.WithBoomCommitLogPrintf ++
  new boom.common.WithNMegaBooms(1) ++
  new chipyard.config.AbstractConfig)

class HyperscaleMegaBoomBaseConfig16MBL2 extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=16*1024) ++
  new HyperscaleMegaBoomBaseConfig)

class HyperscaleMegaBoomBaseConfig16MBL2And8MemChan extends Config(
  new freechips.rocketchip.subsystem.WithNMemoryChannels(8) ++
  new HyperscaleMegaBoomBaseConfig16MBL2)

class HyperscaleSoCTapeout extends Config(
  new compressacc.WithSnappyCompleteASIC ++
  new HyperscaleMegaBoomBaseConfig16MBL2And8MemChan)

// protoacc mega boom configs
class ProtoSerMegaBoomConfig extends Config(
  new protoacc.WithProtoAccelSerOnly ++
  new HyperscaleMegaBoomBaseConfig)

class ProtoDeserMegaBoomConfig extends Config(
  new protoacc.WithProtoAccelDeserOnly ++
  new HyperscaleMegaBoomBaseConfig)

// compress-acc mega boom configs
class SnappyDecompressorHyperscaleMegaBoomConfig extends Config(
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleMegaBoomBaseConfig)

// NEW CONFIGS

class IntegrationConfig extends Config(
  new chipyard.config.WithMultiRoCC ++

  // small
  new chipyard.config.WithMultiRoCCSnappyDecompressor(0) ++
  new chipyard.config.WithMultiRoCCSnappyCompressor(0) ++
  new chipyard.config.WithMultiRoCCProtoAccelDeser(0) ++
  new chipyard.config.WithMultiRoCCProtoAccelSer(0) ++
  new chipyard.config.WithAES192(0x70000000L, 0xFFL, "aes_small") ++
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++

  // big
  new compressacc.WithHufSpeculationAmount(32) ++
  new chipyard.config.WithMultiRoCCZstdDecompressor(1) ++
  new chipyard.config.WithMultiRoCCZstdCompressor(1) ++
  new chipyard.config.WithMultiRoCCProtoAccelDeser(1) ++
  new chipyard.config.WithMultiRoCCProtoAccelSer(1) ++
  new chipyard.config.WithAES192(0x70010000L, 0xFFL, "aes_large") ++


  new freechips.rocketchip.subsystem.WithNBigCores(2) ++
  new HyperscaleRocketBaseConfig)

import freechips.rocketchip.subsystem.{ExtBus, ExtMem, MemoryPortParams, MasterPortParams, SlavePortParams, MemoryBusKey}
import freechips.rocketchip.diplomacy._
import testchipip.{SerialTLKey}

// needs to be able to access the memory space of the smartnic
class AppSoCConfig extends Config(
  new Config((site, here, up) => {
    case ExtBus => Some(MasterPortParams(
      base = x"a000_0000",
      size = x"1000_0000",
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  }) ++
  new HyperscaleRocketBaseConfig)

import freechips.rocketchip.devices.tilelink.{CLINTParams, CLINTKey}
import testchipip.{BootAddrRegKey}

class SmartNICSoCConfig extends Config(
  // setup memory to be at different location
  new Config((site, here, up) => {
    case ExtMem => Some(MemoryPortParams(MasterPortParams(
      base = x"a000_0000",
      size = x"1000_0000",
      beatBytes = site(MemoryBusKey).beatBytes,
      idBits = 4), // ?? changes nothing
      1 // 1 mem. channels
    ))
  }) ++
  // setup slave port (slave to AppSoC)
  new Config((site, here, up) => {
    case ExtIn => Some(SlavePortParams(
      beatBytes = 8, // 64b of data per xfer
      idBits = 4, // 4b of source
      sourceBits = 1 // ?? changes nothing
    ))
  }) ++
  // TODO: have this be autoconfigured by the ExtMem key
  new Config((site, here, up) => {
    // disable tsi on this soc
    case SerialTLKey => None
    // move CLINT to know addr
    case CLINTKey => Some(CLINTParams(baseAddress = x"b000_0000"))
    // have bootrom jump to proper dram loc
    case BootAddrRegKey => up(BootAddrRegKey).map(_.copy(defaultBootAddress = x"a000_0000", defaultClintAddress = x"b000_0000"))
  }) ++
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++
  new HyperscaleRocketBaseConfig)

import chipyard.harness.{MultiHarnessBinder, HasHarnessInstantiators}
import freechips.rocketchip.util.{HeterogeneousBag}
import freechips.rocketchip.tilelink.{TLBundle}

class WithMultiChipTLBus(chip0: Int, chip1: Int) extends MultiHarnessBinder(chip0, chip1, (
  (system0: CanHaveCustomMasterTLMMIOPort, system1: CanHaveCustomSlaveTLPort,
    th: HasHarnessInstantiators,
    ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]]
  ) => {
    require(ports0.size == ports1.size)
    (ports0 zip ports1).map { case (l, r) =>
      println(s"Size of ports to connect: ${l} ${r} ${l.getWidth} ${r.getWidth}")
      require(l.asUInt.getWidth == r.asUInt.getWidth)
      l <> r
    }
  }
))

class IntegrationConfig2 extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithMultiChipTLBus(0, 1) ++
  new chipyard.harness.WithMultiChip(0,
    new AppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new SmartNICSoCConfig))
