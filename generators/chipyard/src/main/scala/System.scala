//******************************************************************************
// Copyright (c) 2019 - 2019, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

package chipyard

import chisel3._

import org.chipsalliance.cde.config.{Parameters, Field}
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.devices.tilelink._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util.{DontTouch}
import freechips.rocketchip.util._

// ---------------------------------------------------------------------
// Base system that uses the debug test module (dtm) to bringup the core
// ---------------------------------------------------------------------

/**
 * Base top with periphery devices and ports, and a BOOM + Rocket subsystem
 */
class ChipyardSystem(implicit p: Parameters) extends ChipyardSubsystem
  with HasAsyncExtInterrupts
  with CanHaveMasterTLMemPort // export TL port for outer memory
  with CanHaveMasterAXI4MemPort // expose AXI port for outer mem
  //with CanHaveMasterAXI4MMIOPort
  //with CanHaveSlaveAXI4Port
  with CanHaveCustomMasterTLMMIOPort
  with CanHaveCustomSlaveTLPort
  with CanHaveCustomMasterTLMMIOPort2
  with CanHaveCustomSlaveTLPort2
{

  val bootROM  = p(BootROMLocated(location)).map { BootROM.attach(_, this, CBUS) }
  val maskROMs = p(MaskROMLocated(location)).map { MaskROM.attach(_, this, CBUS) }

  override lazy val module = new ChipyardSystemModule(this)
}

/**
 * Base top module implementation with periphery devices and ports, and a BOOM + Rocket subsystem
 */
class ChipyardSystemModule(_outer: ChipyardSystem) extends ChipyardSubsystemModuleImp(_outer)
  with HasRTCModuleImp
  with HasExtInterruptsModuleImp
  with DontTouch

// ------------------------------------
// TL Mem Port Mixin
// ------------------------------------

// Similar to ExtMem but instantiates a TL mem port
case object ExtTLMem extends Field[Option[MemoryPortParams]](None)

/** Adds a port to the system intended to master an TL DRAM controller. */
trait CanHaveMasterTLMemPort { this: BaseSubsystem =>

  require(!(p(ExtTLMem).nonEmpty && p(ExtMem).nonEmpty),
    "Can only have 1 backing memory port. Use ExtTLMem for a TL memory port or ExtMem for an AXI memory port.")

  private val memPortParamsOpt = p(ExtTLMem)
  private val portName = "tl_mem"
  private val device = new MemoryDevice
  private val idBits = memPortParamsOpt.map(_.master.idBits).getOrElse(1)
  private val mbus = tlBusWrapperLocationMap.lift(MBUS).getOrElse(locateTLBusWrapper(SBUS))

  val memTLNode = TLManagerNode(memPortParamsOpt.map({ case MemoryPortParams(memPortParams, nMemoryChannels, _) =>
    Seq.tabulate(nMemoryChannels) { channel =>
      val base = AddressSet.misaligned(memPortParams.base, memPortParams.size)
      val filter = AddressSet(channel * mbus.blockBytes, ~((nMemoryChannels-1) * mbus.blockBytes))

     TLSlavePortParameters.v1(
       managers = Seq(TLSlaveParameters.v1(
         address            = base.flatMap(_.intersect(filter)),
         resources          = device.reg,
         regionType         = RegionType.UNCACHED, // cacheable
         executable         = true,
         supportsGet        = TransferSizes(1, mbus.blockBytes),
         supportsPutFull    = TransferSizes(1, mbus.blockBytes),
         supportsPutPartial = TransferSizes(1, mbus.blockBytes))),
         beatBytes = memPortParams.beatBytes)
    }
  }).toList.flatten)

  mbus.coupleTo(s"memory_controller_port_named_$portName") {
    (memTLNode
      :*= TLBuffer()
      :*= TLSourceShrinker(1 << idBits)
      :*= TLWidthWidget(mbus.beatBytes)
      :*= _)
  }

  val mem_tl = InModuleBody { memTLNode.makeIOs() }
}

/** Adds a TileLink port to the system intended to master an MMIO device bus */
trait CanHaveCustomMasterTLMMIOPort { this: BaseSubsystem =>
  private val mmioPortParamsOpt = p(ExtBus)
  private val portName = "mmio_port_tl"
  private val device = new SimpleBus(portName.kebab, Nil)
  private val sbus = locateTLBusWrapper(SBUS)

  // needs to access:
  //   dev: addr,size
  //   dram: a000_0000,1000_0000
  //   icenic: 1001_6000,1000
  //   clint: b000_0000,1_0000

  val mmioTLNode = TLManagerNode(
    mmioPortParamsOpt.map(params => {
      val dramAS = AddressSet.misaligned(params.base, params.size)
      val icenicAS = AddressSet(x"1001_6000", x"fff")
      val clintAS = AddressSet(x"b000_0000", x"ffff")
      val overallAS = dramAS :+ icenicAS :+ clintAS
      TLSlavePortParameters.v1(
        managers = Seq(TLSlaveParameters.v1(
          address            = overallAS,
          resources          = device.ranges,
          executable         = params.executable,
          supportsGet        = TransferSizes(1, 4096),
          supportsPutFull    = TransferSizes(1, 4096),
          supportsPutPartial = TransferSizes(1, 4096))),
        beatBytes = params.beatBytes,
      )
    }).toSeq)

  mmioPortParamsOpt.map { params =>
    sbus.coupleTo(s"port_named_$portName") {
      (mmioTLNode
        := TLBuffer()
        := TLSourceShrinker(1 << params.idBits)
        := TLWidthWidget(sbus.beatBytes)
        := _ )
    }
  }

  val mmio_tl = InModuleBody {
    mmioTLNode.out.foreach { case (_, edge) => println(edge.prettySourceMapping(s"TL MMIO Port")) }
    mmioTLNode.makeIOs()
  }
}

/** Adds an TL port to the system intended to be a slave on an MMIO device bus.
  * NOTE: this port is NOT allowed to issue Acquires.
  */
trait CanHaveCustomSlaveTLPort { this: BaseSubsystem =>
  private val slavePortParamsOpt = p(ExtIn)
  private val portName = "slave_port_tl"
  private val sbus = locateTLBusWrapper(SBUS)

  val l2FrontendTLNode = TLClientNode(
    slavePortParamsOpt.map(params =>
      TLMasterPortParameters.v1(
        clients = Seq(TLMasterParameters.v1(
          name     = portName.kebab,
          sourceId = IdRange(0, 1 << params.idBits),
        )),
        )).toSeq)

  slavePortParamsOpt.map { params =>
    sbus.coupleFrom(s"port_named_$portName") {
      ( _
        := TLFilter(TLFilter.mMaskCacheable)
        := TLSourceShrinker(1 << params.sourceBits)
        := TLWidthWidget(params.beatBytes)
        := l2FrontendTLNode )
    }
  }

  val l2_frontend_bus_tl = InModuleBody { l2FrontendTLNode.makeIOs() }
}

case object ExtBus2 extends Field[Option[MasterPortParams]](None)
case object ExtIn2 extends Field[Option[SlavePortParams]](None)

/** Adds a TileLink port to the system intended to master an MMIO device bus */
trait CanHaveCustomMasterTLMMIOPort2 { this: BaseSubsystem =>
  private val mmioPortParamsOpt = p(ExtBus2)
  private val portName = "mmio_port_tl"
  private val device = new SimpleBus(portName.kebab, Nil)
  private val sbus = locateTLBusWrapper(SBUS)

  // needs to access:
  //   dev: addr,size
  //   dram: 8000_0000,1000_0000

  val mmioTLNode2 = TLManagerNode(
    mmioPortParamsOpt.map(params => {
      val dramAS = AddressSet.misaligned(params.base, params.size)
      val overallAS = dramAS
      TLSlavePortParameters.v1(
        managers = Seq(TLSlaveParameters.v1(
          address            = overallAS,
          resources          = device.ranges,
          executable         = params.executable,
          supportsGet        = TransferSizes(1, 4096),
          supportsPutFull    = TransferSizes(1, 4096),
          supportsPutPartial = TransferSizes(1, 4096))),
        beatBytes = params.beatBytes,
      )
    }).toSeq)

  mmioPortParamsOpt.map { params =>
    sbus.coupleTo(s"port_named_$portName") {
      (mmioTLNode2
        := TLBuffer()
        := TLSourceShrinker(1 << params.idBits)
        := TLWidthWidget(sbus.beatBytes)
        := _ )
    }
  }

  val mmio_tl2 = InModuleBody {
    mmioTLNode2.out.foreach { case (_, edge) => println(edge.prettySourceMapping(s"TL MMIO Port")) }
    mmioTLNode2.makeIOs()
  }
}

/** Adds an TL port to the system intended to be a slave on an MMIO device bus.
  * NOTE: this port is NOT allowed to issue Acquires.
  */
trait CanHaveCustomSlaveTLPort2 { this: BaseSubsystem =>
  private val slavePortParamsOpt = p(ExtIn2)
  private val portName = "slave_port_tl"
  private val sbus = locateTLBusWrapper(SBUS)

  val l2FrontendTLNode2 = TLClientNode(
    slavePortParamsOpt.map(params =>
      TLMasterPortParameters.v1(
        clients = Seq(TLMasterParameters.v1(
          name     = portName.kebab,
          sourceId = IdRange(0, 1 << params.idBits),
        )),
        )).toSeq)

  slavePortParamsOpt.map { params =>
    sbus.coupleFrom(s"port_named_$portName") {
      ( _
        := TLFilter(TLFilter.mMaskCacheable)
        := TLSourceShrinker(1 << params.sourceBits)
        := TLWidthWidget(params.beatBytes)
        := l2FrontendTLNode2 )
    }
  }

  val l2_frontend_bus_tl2 = InModuleBody { l2FrontendTLNode2.makeIOs() }
}
