package chipyard

import chisel3._
import chisel3.util.{DecoupledIO}
import chisel3.reflect.{DataMirror}
import org.chipsalliance.cde.config.{Config}
import freechips.rocketchip.subsystem._
import freechips.rocketchip.subsystem.{ExtBus, ExtMem, MemoryPortParams, MasterPortParams, SlavePortParams, MemoryBusKey}
import freechips.rocketchip.diplomacy._
import testchipip.serdes.{SerialTLKey}
import freechips.rocketchip.devices.tilelink.{CLINTParams, CLINTKey}
import testchipip.boot.{BootAddrRegKey}
import chipyard.harness.{MultiHarnessBinder, HasHarnessInstantiators}
import org.chipsalliance.diplomacy.nodes.{HeterogeneousBag}
import freechips.rocketchip.util.{plusarg_reader, AsyncResetReg}
import freechips.rocketchip.tilelink.{TLBundle, TLBundleA, TLBundleD}
import chipyard.iobinders.{TLMMIOPort, TLInPort, TLMMIO2Port, TLIn2Port}
import testchipip.soc.{BankedScratchpadParams}



// --------------------------------------------------------------------------------------
// Rocket Configs
// --------------------------------------------------------------------------------------

class HyperscaleRocketBaseConfig extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=2048) ++
  new freechips.rocketchip.subsystem.WithNBanks(8) ++
  new chipyard.config.WithExtMemIdBits(7) ++
  new freechips.rocketchip.subsystem.WithNMemoryChannels(1) ++
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

//// compress-acc rocket configs
//class SnappyDecompressorHyperscaleRocketConfig extends Config(
//  new compressacc.WithSnappyDecompressor ++
//  new HyperscaleRocketBaseConfig)
//
//class SnappyDecompressorHyperscaleRocketConfig16MBL2 extends Config(
//  new compressacc.WithSnappyDecompressor ++
//  new HyperscaleRocketBaseConfig16MBL2)
//
//class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChan extends Config(
//  new compressacc.WithSnappyDecompressor ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChan extends Config(
//  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanRoCC extends Config(
//  new compressacc.AcceleratorPlacementRoCC ++
//  new compressacc.WithSnappyCompleteFireSim ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeNoCache ++
//  new compressacc.WithSnappyCompleteFireSim ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeLocalCache ++
//  new compressacc.WithSnappyCompleteFireSim ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyBothFireSimHyperscaleRocketConfig16MBL2And8MemChanChiplet extends Config(
//  new compressacc.AcceleratorPlacementChiplet ++
//  new compressacc.WithSnappyCompleteFireSim ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeNoCache ++
//  new compressacc.WithSnappyDecompressor ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeNoCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeNoCache ++
//  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeLocalCache ++
//  new compressacc.WithSnappyDecompressor ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPCIeLocalCache extends Config(
//  new compressacc.AcceleratorPlacementPCIeLocalCache ++
//  new compressacc.WithSnappyCompressorRuntimeOverprovision ++
//  new HyperscaleRocketBaseConfig16MBL2And8MemChan)
//
//class SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChanPrintf extends Config(
//  new compressacc.WithCompressAccelPrintf ++
//  new SnappyCompressorHyperscaleRocketConfig16MBL2And8MemChan)
//
//class SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChanPrintf extends Config(
//  new compressacc.WithCompressAccelPrintf ++
//  new SnappyDecompressorHyperscaleRocketConfig16MBL2And8MemChan)

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
  new boom.v3.common.WithBoomCommitLogPrintf ++
  new boom.v3.common.WithNMegaBooms(1) ++
  new chipyard.config.AbstractConfig)

class HyperscaleMegaBoomBaseConfig16MBL2 extends Config(
  new freechips.rocketchip.subsystem.WithInclusiveCache(nWays=16, capacityKB=16*1024) ++
  new HyperscaleMegaBoomBaseConfig)

class HyperscaleMegaBoomBaseConfig16MBL2And8MemChan extends Config(
  new freechips.rocketchip.subsystem.WithNMemoryChannels(8) ++
  new HyperscaleMegaBoomBaseConfig16MBL2)

//class HyperscaleSoCTapeout extends Config(
//  new compressacc.WithSnappyCompleteASIC ++
//  new HyperscaleMegaBoomBaseConfig16MBL2And8MemChan)

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

class WithAppSoCModifications extends Config(
  // setup slave port (slave to slave to SmartNICSoC)
  new Config((site, here, up) => {
    case ExtIn2 => Some(SlavePortParams(
      beatBytes = 8, // 64b of data per xfer
      idBits = 4, // 4b of source
      sourceBits = 1 // ?? changes nothing
    ))
  }) ++
  // setup master port (master to SmartNICSoC)
  new Config((site, here, up) => {
    case ExtBus => Some(MasterPortParams(
      base = 0xa000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  })
)

class WithSmartNICSoCModifications extends Config(
  // TODO: unsure why it doesn't work
  //// dramatically increase the baudrate so that things can finish faster
  //new chipyard.harness.WithUARTAdapter(115200 * 12 * 12) ++ // overrides previous binder
  //new chipyard.config.WithUARTInitBaudRate(115200 * 12 * 12) ++
  // TODO: have this be autoconfigured by the ExtMem key
  new Config((site, here, up) => {
    // disable tsi on this soc
    case SerialTLKey => Nil
    // move CLINT to know addr
    case CLINTKey => Some(CLINTParams(baseAddress = 0xb000_0000))
    // have bootrom jump to proper dram loc
    case BootAddrRegKey => up(BootAddrRegKey).map(_.copy(defaultBootAddress = 0xa000_0000, defaultClintAddress = 0xb000_0000))
  }) ++
  // setup memory to be at different location
  new Config((site, here, up) => {
    case ExtMem => Some(MemoryPortParams(MasterPortParams(
      base = 0xa000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes,
      idBits = 7), // has to be 7 to match the app soc
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
  // setup master port (master to AppSoC)
  new Config((site, here, up) => {
    case ExtBus2 => Some(MasterPortParams(
      base = 0x8000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  })
)

object ConnectWithLatency {
  def apply(latency_arg: String, th: HasHarnessInstantiators, ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]], freqStr: String = "clock_500MHz", freqInt: Int = 500): Unit = {
    require(ports0.size == ports1.size)

    val latency_doc = "Latency (cycles) of TL port between both SoC's"
    val my_plusarg_module = Module(new plusarg_reader(s"${latency_arg}=%d", 0, latency_doc, 32))
    val latency = my_plusarg_module.io.out
    midas.targetutils.PlusArg(my_plusarg_module)

    (ports0 zip ports1).map { case (p0hb, p1hb) =>
      // connect the HeterogeneousBag[TLBundle]
      (p0hb zip p1hb).map { case (ll, rr) =>
        // this is a TLBundle
        println(s"DEBUG: (${ll} ?= ${rr}) (${ll.getWidth} ?= ${rr.getWidth}) (${ll.params} ?= ${rr.params})")
        require(ll.params == rr.params, "DEBUG: Ensure the TLBundles can be connected")
        require(!ll.params.hasBCE, "DEBUG: Only supports TL-UC")

        // HACK! Using the same clock as the buses they are connected to
        val tClk = th.harnessClockInstantiator.requestClockMHz(freqStr, freqInt)
        val tReset = AsyncResetReg(false.B, tClk, th.harnessBinderReset.asBool, true, None)

        // connect the fields of the TLBundle
        DataMirror.specifiedDirectionOf(ll.a.ready) match {
          case SpecifiedDirection.Input =>
            withClockAndReset(tClk, tReset) {
              val qa = Module(new latqueue.LatencyInjectionQueue(DataMirror.internal.chiselTypeClone[TLBundleA](ll.a.bits), 128))
              //qa.clock := tClk
              //qa.reset := tReset
              val qd = Module(new latqueue.LatencyInjectionQueue(DataMirror.internal.chiselTypeClone[TLBundleD](rr.d.bits), 128))
              //qd.clock := tClk
              //qd.reset := tReset
              qa.io.latency_cycles := latency
              qd.io.latency_cycles := latency
              qa.io.enq <> ll.a
              rr.a <> qa.io.deq
              qd.io.enq <> rr.d
              ll.d <> qd.io.deq
              //rr.a <> ll.a
              //ll.d <> rr.d
            }
          case SpecifiedDirection.Output => require(false, "Not supported")
          case _ => require(false, "Not supported")
        }
      }
    }
  }
}

class WithA2SNTLBus(chip0: Int, chip1: Int, freqStr: String = "clock_500MHz", freqInt: Int = 500) extends MultiHarnessBinder(
  chip0, chip1,
  (p0: TLMMIOPort) => true,
  (p1: TLInPort) => true,
  (th: HasHarnessInstantiators, p0: TLMMIOPort, p1: TLInPort) => {
    ConnectWithLatency("link_lat_a2s", th, Seq(p0.io), Seq(p1.io), freqStr, freqInt)
  }
)

class WithSN2ATLBus(chip0: Int, chip1: Int, freqStr: String = "clock_500MHz", freqInt: Int = 500) extends MultiHarnessBinder(
  chip0, chip1,
  (p0: TLMMIO2Port) => true,
  (p1: TLIn2Port) => true,
  (th: HasHarnessInstantiators, p0: TLMMIO2Port, p1: TLIn2Port) => {
    ConnectWithLatency("link_lat_s2a", th, Seq(p0.io), Seq(p1.io), freqStr, freqInt)
  }
)

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// DO NOT CHANGE ABOVE THIS UNLESS YOU KNOW WHAT YOU ARE DOING
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class AESConfig extends Config(
  new aes.WithAESCBCAccel ++
  new HyperscaleRocketBaseConfig)

class MemCpyConfig extends Config(
  new memcpyacc.WithMemcpyAccel ++
  new HyperscaleRocketBaseConfig)

class ProtoBaseConfig extends Config(
  new freechips.rocketchip.subsystem.WithoutTLMonitors ++
  new freechips.rocketchip.subsystem.WithExtMemSize((1<<30) * 8L) ++
//  new chipyard.config.WithSV39 ++
  new HyperscaleRocketBaseConfig)

class SerProtoConfig extends Config(
  new protoacc.WithProtoAccelSerOnly ++
  new ProtoBaseConfig)

class DesProtoConfig extends Config(
  new protoacc.WithProtoAccelDeserOnly ++
  new ProtoBaseConfig)

// ---------------------------------

class ReRoCCHyperscaleConfig extends Config(
  //new rerocc.WithReRoCC ++
  new compressacc.WithZstdDecompressor32 ++
  new compressacc.WithZstdCompressor ++
  new ProtoBaseConfig)

class ProtoSerDesHyperscaleConfig extends Config(
  new rerocc.WithReRoCC ++
  new protoacc.WithProtoAccelSerOnly ++
  new protoacc.WithProtoAccelDeserOnly ++
  new ProtoBaseConfig)

// ---------------------------------

class SnappyDeCConfig extends Config(
  new freechips.rocketchip.subsystem.WithExtMemSize((1 << 30) * 1L) ++
  new compressacc.WithSnappyDecompressor ++
  new HyperscaleRocketBaseConfig)

class SnappyCConfig extends Config(
  new freechips.rocketchip.subsystem.WithExtMemSize((1 << 30) * 1L) ++
  new compressacc.WithSnappyCompressor ++
  new HyperscaleRocketBaseConfig)

class ZstdDeCConfig extends Config(
  new freechips.rocketchip.subsystem.WithExtMemSize((1 << 30) * 1L) ++
  new compressacc.WithZstdDecompressor32 ++
  new HyperscaleRocketBaseConfig)

class ZstdCConfig extends Config(
  new freechips.rocketchip.subsystem.WithExtMemSize((1 << 30) * 1L) ++
  new compressacc.WithZstdCompressor ++
  new HyperscaleRocketBaseConfig)

class ZstdConfig extends Config(
  new rerocc.WithReRoCC ++
  new freechips.rocketchip.subsystem.WithExtMemSize((1 << 30) * 1L) ++
  //new compressacc.WithZstdDecompressor32 ++
  new compressacc.WithZstdCompressor ++
  new HyperscaleRocketBaseConfig)

class HyperBoomConfig extends Config(
  new HyperscaleMegaBoomBaseConfig)

// ---------------------------------

class FastBuildAppSoCConfig extends Config(
  new WithAppSoCModifications ++
  new HyperscaleRocketBaseConfig)

class FastBuildSmartNICSoCConfig extends Config(
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++
  new WithSmartNICSoCModifications ++
  new HyperscaleRocketBaseConfig)

class FastBuildIntegrationConfig extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithSN2ATLBus(1, 0) ++ // SoC1 is mastering so it goes 1st
  new WithA2SNTLBus(0, 1) ++
  new chipyard.harness.WithMultiChip(0,
    new FastBuildAppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new FastBuildSmartNICSoCConfig))

// ---------------------------------

class AppSoCConfig extends Config(
  new compressacc.WithSnappyDecompressor ++
  new compressacc.WithSnappyCompressor ++
  new protoacc.WithProtoAccelSerOnly ++
  new protoacc.WithProtoAccelDeserOnly ++
  new memcpyacc.WithMemcpyAccel ++
  new aes.WithAESCBCAccel ++
  new WithAppSoCModifications ++
  new HyperscaleMegaBoomBaseConfig)

class SmartNICSoCConfig extends Config(
  new compressacc.WithZstdDecompressor16 ++
  new Config((site, here, up) => {
    case compressacc.ZstdLiteralLengthMaxAccuracy => 6
    case compressacc.ZstdMatchLengthMaxAccuracy => 6
    case compressacc.ZstdOffsetMaxAccuracy => 5
  }) ++
  new compressacc.WithZstdCompressor ++
  new protoacc.WithProtoAccelSerOnly ++
  new protoacc.WithProtoAccelDeserOnly ++
  new memcpyacc.WithMemcpyAccel ++
  new aes.WithAESCBCAccel ++
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC(inBufFlits = 8192, ctrlQueueDepth = 64) ++ // match FireSim def.
  new WithSmartNICSoCModifications ++
  new HyperscaleRocketBaseConfig)

class IntegrationConfig extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithSN2ATLBus(1, 0) ++ // SoC1 is mastering so it goes 1st
  new WithA2SNTLBus(0, 1) ++
  new chipyard.harness.WithMultiChip(0,
    new AppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new SmartNICSoCConfig))

// -- temp

class WithAppSoCMinModifications extends Config(
  // setup slave port (slave to slave to SmartNICSoC)
  new Config((site, here, up) => {
    case ExtIn2 => Some(SlavePortParams(
      beatBytes = 8, // 64b of data per xfer
      idBits = 3, // 3b of source
      sourceBits = 1 // ?? changes nothing
    ))
  }) ++
  // setup master port (master to SmartNICSoC)
  new Config((site, here, up) => {
    case ExtBus => Some(MasterPortParams(
      base = 0xa000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  })
)

class WithSmartNICSoCMinModifications extends Config(
  // TODO: unsure why it doesn't work
  //// dramatically increase the baudrate so that things can finish faster
  //new chipyard.harness.WithUARTAdapter(115200 * 12 * 12) ++ // overrides previous binder
  //new chipyard.config.WithUARTInitBaudRate(115200 * 12 * 12) ++
  // TODO: have this be autoconfigured by the ExtMem key
  new Config((site, here, up) => {
    // disable tsi on this soc
    case SerialTLKey => Nil
    // move CLINT to know addr
    case CLINTKey => Some(CLINTParams(baseAddress = 0xb000_0000))
    // have bootrom jump to proper dram loc
    case BootAddrRegKey => up(BootAddrRegKey).map(_.copy(defaultBootAddress = 0xa000_0000, defaultClintAddress = 0xb000_0000))
  }) ++
  // setup memory to be at different location
  new Config((site, here, up) => {
    case ExtMem => Some(MemoryPortParams(MasterPortParams(
      base = 0xa000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes,
      idBits = 7), // has to be 7 to match the app soc
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
  // setup master port (master to AppSoC)
  new Config((site, here, up) => {
    case ExtBus2 => Some(MasterPortParams(
      base = 0x8000_0000,
      size = 0x1000_0000,
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  })
)


class AppSoCMinimalConfig extends Config(
  new WithAppSoCMinModifications ++
  //new HyperscaleMegaBoomBaseConfig)
  new HyperscaleRocketBaseConfig)

class SmartNICSoCMinimalConfig extends Config(
  new WithSmartNICSoCMinModifications ++
  new HyperscaleRocketBaseConfig)

class MinimalIntegrationConfig extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithSN2ATLBus(1, 0) ++ // SoC1 is mastering so it goes 1st
  new WithA2SNTLBus(0, 1) ++
  new chipyard.harness.WithMultiChip(0,
    new AppSoCMinimalConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new SmartNICSoCMinimalConfig))

// ---------------------------------
