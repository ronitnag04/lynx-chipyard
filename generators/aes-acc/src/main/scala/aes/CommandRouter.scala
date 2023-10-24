package aes

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters}
import freechips.rocketchip.util.DecoupledHelper

class CommandRouter(val cmd_queue_depth: Int)(implicit val p: Parameters) extends StreamingCommandRouter {
  class AesStreamerCmdBundle()(implicit p: Parameters) extends MemStreamerCmdBundle {
    val num_bytes = Decoupled(UInt(32.W))
    val key = Valid(UInt(256.W))
    val mode = Valid(Bool())
  }
  lazy val io = IO(new AesStreamerCmdBundle) // lazy matters

  val FUNCT_MODE                          = 4.U
  val FUNCT_KEY_0                         = 5.U
  val FUNCT_KEY_1                         = 6.U

  io.num_bytes.bits := src_info_queue.io.deq.bits.isize
  io.num_bytes.valid := src_info_queue.io.deq.fire()

  // Mode interface
  val mode_queue = Module(new Queue(Bool(), cmd_queue_depth))
  mode_queue.io.enq.bits := cur_rs1
  val mode_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_MODE,
    mode_queue.io.enq.ready
  )
  mode_queue.io.enq.valid := mode_fire.fire(mode_queue.io.enq.ready)
  io.mode.bits <> mode_queue.io.deq.bits
  io.mode.valid <> mode_queue.io.deq.valid
  mode_queue.io.deq.ready := true.B

  // Key interface
  val key_queue = Module(new Queue(UInt(256.W), cmd_queue_depth))
  val key_lower_128 = RegInit(0.U(128.W))
  val key0_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_KEY_0,
    key_queue.io.enq.ready
  )
  when (key0_fire.fire(key_queue.io.enq.ready)) {
    key_lower_128 := Cat(cur_rs1, cur_rs2)
  }
  val key1_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_KEY_1,
    key_queue.io.enq.ready
  )
  key_queue.io.enq.valid := key1_fire.fire(key_queue.io.enq.ready)
  key_queue.io.enq.bits := Cat(Cat(cur_rs1, cur_rs2), key_lower_128)
  io.key.bits <> key_queue.io.deq.bits
  io.key.valid <> key_queue.io.deq.valid
  key_queue.io.deq.ready := true.B

  // streaming_fire provided by StreamingCommandRouter
  io.rocc_in.ready := streaming_fire ||
    mode_fire.fire(io.rocc_in.valid) ||
    key0_fire.fire(io.rocc_in.valid) ||
    key1_fire.fire(io.rocc_in.valid)
}
