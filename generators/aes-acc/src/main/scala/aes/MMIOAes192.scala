//--------------------------------------------------------------------------------------
// Copyright 2022 Massachusets Institute of Technology
// SPDX short identifier: BSD-2-Clause
//
// File         : aes.scala
// Project      : Common Evaluation Platform (CEP)
// Description  : TileLink interface to the verilog AES core
//
// Adapted without the LLKI interface from MIT
//--------------------------------------------------------------------------------------
package aes

import chisel3._
import chisel3.util._
import chisel3.experimental.{IntParam, BaseModule}
import org.chipsalliance.cde.config.{Field, Parameters}
import freechips.rocketchip.subsystem.{BaseSubsystem, PeripheryBusKey}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper._
import freechips.rocketchip.tilelink._

//--------------------------------------------------------------------------------------
// BEGIN: Module "Periphery" connections
//--------------------------------------------------------------------------------------

// Parameters associated with the core
case object PeripheryAES192Key extends Field[Seq[AES192Params]](Nil)

object AES192Addresses {
  val aes_ctrlstatus_addr           = 0x0000
  val aes_pt0_addr                  = 0x0008
  val aes_pt1_addr                  = 0x0010
  val aes_ct0_addr                  = 0x0018
  val aes_ct1_addr                  = 0x0020
  val aes_key0_addr                 = 0x0028
  val aes_key1_addr                 = 0x0030
  val aes_key2_addr                 = 0x0038
}

// The following class is used to pass paramaters down into the CEP cores
case class AES192Params(
  slave_base_addr     : BigInt,
  slave_depth         : BigInt,
  dev_name            : String,			// Device name as it will appear in the Device Tree
  verilog_module_name : Option[String] = None	// Allows for override of the Blackbox module & instantiation name
)

// The following parameter pass attachment info to the lower level objects/classes/etc.
case class AES192AttachParams(
  coreparams          : AES192Params,
  slave_bus           : TLBusWrapper
)

// This trait "connects" the core to the Rocket Chip and passes the parameters down
// to the instantiation
trait CanHavePeripheryAES192 { this: BaseSubsystem =>
  val aesnode = p(PeripheryAES192Key).map { params =>

    // Initialize the attachment parameters
    val coreattachparams = AES192AttachParams(
      coreparams  = params,
      slave_bus   = pbus
    )

    // Instantiate th TL module.  Note: This name shows up in the generated verilog hiearchy
    // and thus should be unique to this core and NOT a verilog reserved keyword
    val aesmodule = LazyModule(new aesTLModule(coreattachparams)(p))

    // Perform the slave "attachments" to the slave bus
    coreattachparams.slave_bus.coupleTo(coreattachparams.coreparams.dev_name + "_slave") {
      aesmodule.slave_node :*=
      TLFragmenter(coreattachparams.slave_bus) :*= _
    }

    // Explicitly connect the clock and reset (the module will be clocked off of the slave bus)
    InModuleBody { aesmodule.module.reset := coreattachparams.slave_bus.module.reset }
    InModuleBody { aesmodule.module.clock := coreattachparams.slave_bus.module.clock }

}}
//--------------------------------------------------------------------------------------
// END: Module "Periphery" connections
//--------------------------------------------------------------------------------------



//--------------------------------------------------------------------------------------
// BEGIN: TileLink Module
//--------------------------------------------------------------------------------------
class aesTLModule(coreattachparams: AES192AttachParams)(implicit p: Parameters) extends LazyModule {
  // Create the RegisterRouter node
  val slave_node = TLRegisterNode(
    address     = Seq(AddressSet(
                    coreattachparams.coreparams.slave_base_addr,
                    coreattachparams.coreparams.slave_depth)),
    device      = new SimpleDevice(coreattachparams.coreparams.dev_name + "-slave",
                    Seq("mitll," + coreattachparams.coreparams.dev_name + "-slave")),
    beatBytes   = coreattachparams.slave_bus.beatBytes
  )

  // Instantiate the implementation
  lazy val module = new aesTLModuleImp(coreattachparams.coreparams, this)

}
//--------------------------------------------------------------------------------------
// END: TileLink Module
//--------------------------------------------------------------------------------------


//--------------------------------------------------------------------------------------
// BEGIN: TileLink Module Implementation
//--------------------------------------------------------------------------------------
class aesTLModuleImp(coreparams: AES192Params, outer: aesTLModule) extends LazyModuleImp(outer) {
  class aes_192_mock_tss() extends BlackBox with HasBlackBoxResource {

    val io = IO(new Bundle {
      // Clock and Reset
      val clk                 = Input(Clock())
      val rst                 = Input(Reset())

      // Inputs
      val start               = Input(Bool())
      val state               = Input(UInt(128.W))
      val key                 = Input(UInt(192.W))

      // Outputs
      val out                 = Output(UInt(128.W))
      val out_valid           = Output(Bool())
    })

    // Add the SystemVerilog/Verilog files associated with the BlackBox
    // Relative to ./src/main/resources
    addResource("/vsrc/aes/aes192/aes_192_mock_tss.sv")
    addResource("/vsrc/aes/aes192/aes_192.v")
    addResource("/vsrc/aes/aes192/round.v")
    addResource("/vsrc/aes/aes192/table.v")

    //Common Resources used by all modules (LLKI, Opentitan, etc.)

      // Provide an optional override of the Blackbox module name
    override def desiredName(): String = {
      return coreparams.verilog_module_name.getOrElse(super.desiredName)
    }
  }

  // Instantiate the blackbox
  val aes_192_inst   = Module(new aes_192_mock_tss())

  // Provide an optional override of the Blackbox module instantiation name
  aes_192_inst.suggestName(aes_192_inst.desiredName()+"_inst")

  // Instantiate registers for the blackbox inputs
  val start               = RegInit(0.U(1.W))
  val state0              = RegInit(0.U(64.W))
  val state1              = RegInit(0.U(64.W))
  val key0                = RegInit(0.U(64.W))
  val key1                = RegInit(0.U(64.W))
  val key2                = RegInit(0.U(64.W))
  val out                 = Wire(UInt(128.W))
  val out_valid           = Wire(Bool())

  // Map the core specific blackbox IO
  aes_192_inst.io.clk    := clock
  aes_192_inst.io.rst    := reset
  aes_192_inst.io.start  := start
  aes_192_inst.io.state  := Cat(state0, state1)
  aes_192_inst.io.key    := Cat(key0, key1, key2)
  out                    := aes_192_inst.io.out
  out_valid              := aes_192_inst.io.out_valid

  // Define the register map
  // Registers with .r suffix to RegField are Read Only (otherwise, Chisel will assume they are R/W)
  outer.slave_node.regmap (
    AES192Addresses.aes_ctrlstatus_addr -> RegFieldGroup("aes_ctrlstatus", Some("AES_Control_Status_Register"),Seq(
      RegField    (1, start,      RegFieldDesc("start", "")),
      RegField.r  (1, out_valid,  RegFieldDesc("out_valid", "", volatile=true)))),
    AES192Addresses.aes_pt0_addr -> RegFieldGroup("aes_pt0", Some(""), Seq(RegField(64, state0))),
    AES192Addresses.aes_pt1_addr -> RegFieldGroup("aes_pt1", Some(""), Seq(RegField(64, state1))),
    AES192Addresses.aes_ct0_addr -> RegFieldGroup("aes_ct0", Some(""), Seq(RegField.r(64, out(127,64)))),
    AES192Addresses.aes_ct1_addr -> RegFieldGroup("aes_ct1", Some(""), Seq(RegField.r(64, out(63,0)))),
    AES192Addresses.aes_key0_addr -> RegFieldGroup("aes_key0", Some(""), Seq(RegField(64, key0))),
    AES192Addresses.aes_key1_addr -> RegFieldGroup("aes_key1", Some(""), Seq(RegField(64, key1))),
    AES192Addresses.aes_key2_addr -> RegFieldGroup("aes_key2", Some(""), Seq(RegField(64, key2)))
  )  // regmap

}

//--------------------------------------------------------------------------------------
// END: TileLink Module Implementation
//--------------------------------------------------------------------------------------
