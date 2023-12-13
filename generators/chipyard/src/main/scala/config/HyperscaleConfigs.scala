package chipyard

import chisel3._
import chisel3.util.{DecoupledIO}
import chisel3.experimental.{DataMirror}

import org.chipsalliance.cde.config.{Config}
import freechips.rocketchip.subsystem._
import freechips.rocketchip.subsystem.{ExtBus, ExtMem, MemoryPortParams, MasterPortParams, SlavePortParams, MemoryBusKey}
import freechips.rocketchip.diplomacy._
import testchipip.{SerialTLKey}
import freechips.rocketchip.devices.tilelink.{CLINTParams, CLINTKey}
import testchipip.{BootAddrRegKey}
import chipyard.harness.{MultiHarnessBinder, HasHarnessInstantiators}
import freechips.rocketchip.util.{HeterogeneousBag, PlusArg, AsyncResetReg}
import freechips.rocketchip.tilelink.{TLBundle, TLBundleA, TLBundleD}

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
      base = x"a000_0000",
      size = x"1000_0000",
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
    case SerialTLKey => None
    // move CLINT to know addr
    case CLINTKey => Some(CLINTParams(baseAddress = x"b000_0000"))
    // have bootrom jump to proper dram loc
    case BootAddrRegKey => up(BootAddrRegKey).map(_.copy(defaultBootAddress = x"a000_0000", defaultClintAddress = x"b000_0000"))
  }) ++
  // setup memory to be at different location
  new Config((site, here, up) => {
    case ExtMem => Some(MemoryPortParams(MasterPortParams(
      base = x"a000_0000",
      size = x"1000_0000",
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
      base = x"8000_0000",
      size = x"1000_0000",
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  })
)

object ConnectWithLatency {
  def apply(isFiresim: Boolean, latency_arg: String, th: HasHarnessInstantiators, ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]], freqStr: String = "clock_500MHz", freqInt: Int = 500): Unit = {
    require(ports0.size == ports1.size)

    val latency_doc = "Latency (cycles) of TL port between both SoC's"
    val latency = if (isFiresim) {
      val l = WireInit(0.U(32.W))
      midas.targetutils.PlusArgs(l, name=s"${latency_arg}=%d", docstring=latency_doc)
      l
    } else {
      PlusArg(latency_arg, docstring=latency_doc)
    }

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
            val qa = Module(new latqueue.LatencyInjectionQueue(DataMirror.internal.chiselTypeClone[TLBundleA](ll.a.bits), 128))
            qa.clock := tClk
            qa.reset := tReset
            val qd = Module(new latqueue.LatencyInjectionQueue(DataMirror.internal.chiselTypeClone[TLBundleD](rr.d.bits), 128))
            qd.clock := tClk
            qd.reset := tReset
            qa.io.latency_cycles := latency
            qd.io.latency_cycles := latency
            qa.io.enq <> ll.a
            rr.a <> qa.io.deq
            qd.io.enq <> rr.d
            ll.d <> qd.io.deq
            //rr.a <> ll.a
            //ll.d <> rr.d
          case SpecifiedDirection.Output => require(false, "Not supported")
          case _ => require(false, "Not supported")
        }
      }
    }
  }
}

class WithA2SNTLBus(chip0: Int, chip1: Int, isFiresim: Boolean = false, freqStr: String = "clock_500MHz", freqInt: Int = 500) extends MultiHarnessBinder(chip0, chip1, (
  (system0: CanHaveCustomMasterTLMMIOPort, system1: CanHaveCustomSlaveTLPort,
    th: HasHarnessInstantiators,
    ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]]
  ) => {
    ConnectWithLatency(isFiresim, "link_lat_a2s", th, ports0, ports1, freqStr, freqInt)
  }
))

class WithSN2ATLBus(chip0: Int, chip1: Int, isFiresim: Boolean = false, freqStr: String = "clock_500MHz", freqInt: Int = 500) extends MultiHarnessBinder(chip0, chip1, (
  (system0: CanHaveCustomMasterTLMMIOPort2, system1: CanHaveCustomSlaveTLPort2,
    th: HasHarnessInstantiators,
    ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]]
  ) => {
    ConnectWithLatency(isFiresim, "link_lat_s2a", th, ports0, ports1, freqStr, freqInt)
  }
))

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// DO NOT CHANGE ABOVE THIS UNLESS YOU KNOW WHAT YOU ARE DOING
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class AESConfig extends Config(
  new aes.WithAES256ECBAccel ++
  new HyperscaleRocketBaseConfig)

class MemCpyConfig extends Config(
  new memcpyacc.WithMemcpyAccel ++
  new HyperscaleRocketBaseConfig)

// ---------------------------------

class AESMemCpyConfig extends Config(
  new aes.WithAES256ECBAccel ++
  new memcpyacc.WithMemcpyAccel ++
  new HyperscaleRocketBaseConfig)

class ProtoConfig extends Config(
  new protoacc.WithProtoAccelSerOnly ++
  new protoacc.WithProtoAccelDeserOnly ++
  new HyperscaleRocketBaseConfig)

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

class FastBuildBaseIntegrationConfig(isFiresim: Boolean = false) extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithSN2ATLBus(1, 0, isFiresim) ++ // SoC1 is mastering so it goes 1st
  new WithA2SNTLBus(0, 1, isFiresim) ++
  new chipyard.harness.WithMultiChip(0,
    new FastBuildAppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new FastBuildSmartNICSoCConfig))

class FastBuildIntegrationConfig extends Config(new FastBuildBaseIntegrationConfig(false))
class FastBuildFireSimIntegrationConfig extends Config(new FastBuildBaseIntegrationConfig(true))

// ---------------------------------

class AppSoCConfig extends Config(
  new compressacc.WithSnappyDecompressor ++
  new compressacc.WithSnappyCompressor ++
  new protoacc.WithProtoAccelSerOnly ++
  new protoacc.WithProtoAccelDeserOnly ++
  new memcpyacc.WithMemcpyAccel ++
  new aes.WithAES256ECBAccel ++
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
  new aes.WithAES256ECBAccel ++
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++
  new WithSmartNICSoCModifications ++
  new HyperscaleRocketBaseConfig)

class IntegrationConfig extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithSN2ATLBus(1, 0, false) ++ // SoC1 is mastering so it goes 1st
  new WithA2SNTLBus(0, 1, false) ++
  new chipyard.harness.WithMultiChip(0,
    new AppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new SmartNICSoCConfig))
