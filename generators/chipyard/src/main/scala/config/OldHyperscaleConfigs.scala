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
  new freechips.rocketchip.subsystem.WithNMemoryChannels(2) ++ // TODO: 2 channels for 1 SoC, 1 for other
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
