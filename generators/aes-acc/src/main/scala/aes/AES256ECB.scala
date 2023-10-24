package aes

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters}
import freechips.rocketchip.util.{DecoupledHelper}
import testchipip.{StreamWidener, StreamNarrower}
import accelip._

import L2MemHelperConsts._
import AES256Consts._

class AES256ECB(val logger: AccelLogger = DefaultAccelLogger)(implicit val p: Parameters) extends MemStreamer {
  class AES256ECBBundle extends MemStreamerBundle {
    val key = Flipped(Valid(UInt(AES256Consts.KEY_SZ_BITS.W))) //from CommandRouter
    val mode = Flipped(Valid(Bool())) //from CommandRouter
  }
  lazy val io = IO(new AES256ECBBundle)

  // Connect AES core to MemLoader (i.e. load_data_queue)

  val aes = Module(new AesCipherCoreDriver)

  assert(BLOCK_SZ_BITS <= BUS_SZ_BITS, "Need the bus bits to be greater than the block bits")

  val snarrower = Module(new StreamNarrower(BUS_SZ_BITS, BLOCK_SZ_BITS))
  snarrower.io.in.bits.last := DontCare
  snarrower.io.in.bits.keep := DontCare
  val swidener = Module(new StreamWidener(BLOCK_SZ_BITS, BUS_SZ_BITS))
  swidener.io.in.bits.last := DontCare
  swidener.io.in.bits.keep := DontCare
  val aes_meta_queue = Module(new Queue(new LiteralChunk, 5)) // used to keep track of chunk_size, is_final_chunk
  dontTouch(aes_meta_queue.io.count)

  val key_queue = RegInit(0.U(AES256Consts.KEY_SZ_BITS.W))
  when (io.key.valid) {
    key_queue := io.key.bits
  }
  val mode_queue = RegInit(false.B)
  when (io.mode.valid) {
    mode_queue := io.mode.bits
  }

  // TODO: encrypting more than necessary (does an extra 128 encrypt/decrypt at the end)

  aes.io.in.bits.key := key_queue
  aes.io.in.bits.encrypt := mode_queue

  aes.io.in.bits.data := snarrower.io.out.bits.data
  aes.io.in.valid := snarrower.io.out.valid
  snarrower.io.out.ready := aes.io.in.ready

  swidener.io.in.bits.data := aes.io.out.bits.data
  swidener.io.in.valid := aes.io.out.valid
  aes.io.out.ready := swidener.io.in.ready

  snarrower.io.in.bits.data := load_data_queue.io.deq.bits.chunk_data
  aes_meta_queue.io.enq.bits := load_data_queue.io.deq.bits

  // TODO: unsure
  val narrow_fire = DecoupledHelper(
    load_data_queue.io.deq.valid,
    snarrower.io.in.ready,
    aes_meta_queue.io.enq.ready
  )
  snarrower.io.in.valid := narrow_fire.fire(snarrower.io.in.ready)
  aes_meta_queue.io.enq.valid := narrow_fire.fire(aes_meta_queue.io.enq.ready)
  load_data_queue.io.deq.ready := narrow_fire.fire(load_data_queue.io.deq.valid)

  // Connect AES core output to MemWriter (i.e. store_data_queue)

  store_data_queue.io.enq.bits.chunk_data := swidener.io.out.bits.data
  store_data_queue.io.enq.bits.chunk_size_bytes := aes_meta_queue.io.deq.bits.chunk_size_bytes
  store_data_queue.io.enq.bits.is_final_chunk := aes_meta_queue.io.deq.bits.is_final_chunk

  // TODO: unsure
  val write_fire = DecoupledHelper(
    swidener.io.out.valid,
    aes_meta_queue.io.deq.valid,
    store_data_queue.io.enq.ready
  )
  store_data_queue.io.enq.valid := write_fire.fire(store_data_queue.io.enq.ready)
  swidener.io.out.ready := write_fire.fire(swidener.io.out.valid)
  aes_meta_queue.io.deq.ready := write_fire.fire(aes_meta_queue.io.deq.valid)
}
