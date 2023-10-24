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

class BaseAppSoCConfig extends Config(
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
  }) ++
  new HyperscaleRocketBaseConfig)

class BaseSmartNICSoCConfig extends Config(
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
  // setup master port (master to AppSoC)
  new Config((site, here, up) => {
    case ExtBus2 => Some(MasterPortParams(
      base = x"8000_0000",
      size = x"1000_0000",
      beatBytes = site(MemoryBusKey).beatBytes, // 64b of data per xfer
      idBits = 4, // 4b of source
      executable = true // left true otherwise it will add extra bundle fields
    ))
  }) ++
  new HyperscaleRocketBaseConfig)

class WithMultiChipTLBus(chip0: Int, chip1: Int, isFiresim: Boolean = false) extends MultiHarnessBinder(chip0, chip1, (
  (system0: CanHaveCustomMasterTLMMIOPort, system1: CanHaveCustomSlaveTLPort,
    th: HasHarnessInstantiators,
    ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]]
  ) => {
    require(ports0.size == ports1.size)

    val latency_arg = "cross_link_latency"
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
        val tClk = th.harnessClockInstantiator.requestClockMHz("clock_500MHz", 500)
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
))

class WithMultiChipTLBus2(chip0: Int, chip1: Int, isFiresim: Boolean = false) extends MultiHarnessBinder(chip0, chip1, (
  (system0: CanHaveCustomMasterTLMMIOPort2, system1: CanHaveCustomSlaveTLPort2,
    th: HasHarnessInstantiators,
    ports0: Seq[HeterogeneousBag[TLBundle]], ports1: Seq[HeterogeneousBag[TLBundle]]
  ) => {
    require(ports0.size == ports1.size)

    val latency_arg = "cross_link_latency2"
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
        val tClk = th.harnessClockInstantiator.requestClockMHz("clock_500MHz", 500)
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
))

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// DO NOT CHANGE ABOVE THIS UNLESS YOU KNOW WHAT YOU ARE DOING
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class AppSoCConfig extends Config(
  //new compressacc.WithSnappyDecompressor ++
  //new compressacc.WithSnappyCompressor ++
  //new protoacc.WithProtoAccelSerOnly ++
  //new protoacc.WithProtoAccelDeserOnly ++
  //new chipyard.config.WithAES192(0x70000000L, 0xFFL, "aes_small") ++
  new BaseAppSoCConfig)

class SmartNICSoCConfig extends Config(
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++
  //new compressacc.WithZstdDecompressor32 ++
  //new compressacc.WithZstdCompressor ++
  //new protoacc.WithProtoAccelSerOnly ++
  //new protoacc.WithProtoAccelDeserOnly ++
  //new chipyard.config.WithAES192(0x70000000L, 0xFFL, "aes_large") ++
  new BaseSmartNICSoCConfig)

class BaseIntegrationConfig(isFiresim: Boolean = false) extends Config(
  new chipyard.harness.WithAbsoluteFreqHarnessClockInstantiator ++   // use absolute freqs for sims in the harness
  new WithMultiChipTLBus2(1, 0, isFiresim) ++ // SoC1 is mastering so it goes 1st
  new WithMultiChipTLBus(0, 1, isFiresim) ++
  new chipyard.harness.WithMultiChip(0,
    new AppSoCConfig) ++
  new chipyard.harness.WithMultiChip(1,
    new SmartNICSoCConfig))

class IntegrationConfig extends Config(new BaseIntegrationConfig(false))
class FireSimIntegrationConfig extends Config(new BaseIntegrationConfig(true))

class AESConfig extends Config(
  new aes.WithAES256ECBAccel ++
  new HyperscaleRocketBaseConfig)

class MemCpyConfig extends Config(
  new memcpyacc.WithMemcpyAccel ++
  new HyperscaleRocketBaseConfig)
