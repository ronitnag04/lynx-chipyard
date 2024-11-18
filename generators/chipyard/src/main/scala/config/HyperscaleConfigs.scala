package chipyard

import org.chipsalliance.cde.config.{Config}
import testchipip.soc.{BankedScratchpadParams}

class HyperscaleReRoCCAccelerators extends Config(
  new rerocc.WithReRoCC(reRoCCManagerParams=rerocc.manager.ReRoCCTileParams(l2TLBEntries=512, l2TLBWays=4)) ++ // matches prior aurora-like setup
  // idN-1
  // Using 256KB spad (*8 = 2MB)
  new compressacc.WithSnappyDecompressor(Some(BankedScratchpadParams(0x70000000L, 256 << 10))) ++
  // new compressacc.WithSnappyCompressor(Some(BankedScratchpadParams(0x61000000L, 256 << 10))) ++
  new compressacc.WithSnappyCompressor(Some(BankedScratchpadParams(0x60000000L, 256 << 10))) ++
  // // TODO: Zstd accs. are too large to duplicate
  // new compressacc.WithZstdDecompressor4(Some(BankedScratchpadParams(0x70000000L, 256 << 10))) ++
  // new compressacc.WithZstdCompressor(Some(BankedScratchpadParams(0x60000000L, 256 << 10))) ++
  new protoacc.WithProtoAccelSerOnly(Some(BankedScratchpadParams(0x51000000L, 256 << 10))) ++
  new protoacc.WithProtoAccelSerOnly(Some(BankedScratchpadParams(0x50000000L, 256 << 10))) ++
  new protoacc.WithProtoAccelDeserOnly(Some(BankedScratchpadParams(0x41000000L, 256 << 10))) ++
  new protoacc.WithProtoAccelDeserOnly(Some(BankedScratchpadParams(0x40000000L, 256 << 10))) ++
  new memcpyacc.WithMemcpyAccel ++
  new memcpyacc.WithMemcpyAccel ++
  new aes.WithAESCBCAccel(Some(BankedScratchpadParams(0x31000000L, 256 << 10))) ++
  new aes.WithAESCBCAccel(Some(BankedScratchpadParams(0x30000000L, 256 << 10)))
  // id0
)

// NIC gives 64 * 3G = 192 Gb/s
class HyperscaleUncore extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=2048) ++ // 256 * 3G = 768Gb/s BW
  new freechips.rocketchip.subsystem.WithNBanks(8) ++
  new chipyard.config.WithExtMemIdBits(7) ++
  new freechips.rocketchip.subsystem.WithNMemoryChannels(4) ++ // 64 * 4 * 1G = 256Gb/s BW
  new chipyard.config.WithSystemBusWidth(256) ++
  new chipyard.config.WithL2TLBs(1024, 4) ++
  new freechips.rocketchip.subsystem.WithoutTLMonitors
)

class HyperscaleNRocketBaseConfig(cores: Int = 1) extends Config(
  new HyperscaleUncore ++
  new freechips.rocketchip.rocket.WithNHugeCores(cores) ++
  new chipyard.config.AbstractConfig)

// class Hyperscale8CoreMegaBoomBaseConfig extends Config(
//   new HyperscaleUncore ++
//   new boom.v3.common.WithCloneBoomTiles(7, 0) ++
//   new boom.v3.common.WithNMegaBooms(1) ++
//   new chipyard.config.AbstractConfig)

// for now using rocket since it works with rerocc
// class HyperscaleTotalConfig extends Config(
//   new HyperscaleReRoCCAccelerators ++
//   new Hyperscale8CoreRocketBaseConfig
// )

class HyperscaleTotal2Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(2)
)

class HyperscaleTotal4Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(4)
)

class HyperscaleTotal8Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(8)
)

class HyperscaleTotal12Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(12)
)

class HyperscaleTotal16Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(16)
)

class HyperscaleTotal24Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(24)
)

class HyperscaleTotal32Config extends Config(
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(32)
)

class DTMHyperscaleTotal8Config extends Config(
  new freechips.rocketchip.rocket.WithCease(false) ++
  new chipyard.config.WithNPMPs(0) ++
  new chipyard.harness.WithSerialTLTiedOff() ++
  new chipyard.config.WithDMIDTM() ++
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(8)
)

class DTMHyperscaleTotal2Config extends Config(
  new freechips.rocketchip.rocket.WithCease(false) ++
  new chipyard.config.WithNPMPs(0) ++
  new chipyard.harness.WithSerialTLTiedOff() ++
  new chipyard.config.WithDMIDTM() ++
  new HyperscaleReRoCCAccelerators ++
  new HyperscaleNRocketBaseConfig(2)
)

class HyperscaleMinimalConfig extends Config(
  new rerocc.WithReRoCC(reRoCCManagerParams=rerocc.manager.ReRoCCTileParams(l2TLBEntries=512, l2TLBWays=4)) ++ // matches prior aurora-like setup
  // idN-1
  new memcpyacc.WithMemcpyAccel ++
  new aes.WithAESCBCAccel(Some(BankedScratchpadParams(0x30000000L, 256 << 10))) ++
  // id0
  new HyperscaleNRocketBaseConfig(1))

class HyperscaleMemcpyConfig extends Config(
  new rerocc.WithReRoCC(reRoCCManagerParams=rerocc.manager.ReRoCCTileParams(l2TLBEntries=512, l2TLBWays=4)) ++ // matches prior aurora-like setup
  // idN-1
  new memcpyacc.WithMemcpyAccel ++
  // id0
  new HyperscaleNRocketBaseConfig(1))

class HyperscaleSnappyCompressConfig extends Config(
  new rerocc.WithReRoCC(reRoCCManagerParams=rerocc.manager.ReRoCCTileParams(l2TLBEntries=512, l2TLBWays=4)) ++ // matches prior aurora-like setup
  // idN-1
  // Using 256KB spad (*8 = 2MB)
  new compressacc.WithSnappyCompressor(Some(BankedScratchpadParams(0x30000000L, 256 << 10))) ++
  new compressacc.WithSnappyDecompressor(Some(BankedScratchpadParams(0x40000000L, 256 << 10))) ++
  // id0
  new HyperscaleNRocketBaseConfig(1))
