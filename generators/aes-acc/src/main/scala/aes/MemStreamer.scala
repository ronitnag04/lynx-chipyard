package aes

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters}
import freechips.rocketchip.util.{DecoupledHelper}

class MemStreamerBundle()(implicit p: Parameters) extends Bundle {
  val num_bytes = Flipped(Decoupled(UInt(32.W))) //from CommandRouter
  val mem_stream = Flipped(new MemLoaderConsumerBundle) //from MemLoader
  val memwrites_in = Decoupled(new WriterBundle) //to MemWriter
}

trait MemStreamer extends Module {
  val io: MemStreamerBundle
  implicit val p: Parameters
  val l2bwBits: Int

  val l2bwBytes = l2bwBits / 8

  // 1. Receive data from the memloader to load_data_queue
  /* Slice data by the L2 bandwidth (assuming 32 bytes).
  ** Different L2 bandwidth will require to change
  ** the memwriter module in Top.scala
  ** and the LiteralChunk bundle in Common.scala. */

  val load_data_queue = Module(new Queue(new LiteralChunk, 5))
  dontTouch(load_data_queue.io.count)

  //TODO: Make sure this remaining_bytes thing works correctly with multiple requests
  val num_bytes_queue = Module(new Queue(UInt(32.W), 5))
  num_bytes_queue.io.enq <> io.num_bytes
  val consumed_bytes = RegInit(0.U(32.W))
  val remaining_bytes = num_bytes_queue.io.deq.bits - consumed_bytes

  //TODO: reset registers(data received, consumed_bytes)
  val data_received = RegInit(0.U(32.W))
  when(load_data_queue.io.enq.ready && load_data_queue.io.enq.valid){
    data_received := data_received + 1.U
  }
  dontTouch(data_received)
  val chunk_size = Mux(remaining_bytes < l2bwBytes.U,
    remaining_bytes % l2bwBytes.U,
    l2bwBytes.U)
  load_data_queue.io.enq.bits.chunk_data := io.mem_stream.output_data
  load_data_queue.io.enq.bits.chunk_size_bytes := chunk_size
  load_data_queue.io.enq.bits.is_final_chunk := (remaining_bytes <= l2bwBytes.U)
  val fire_read = DecoupledHelper(
    io.mem_stream.output_valid,
    load_data_queue.io.enq.ready,
    chunk_size <= io.mem_stream.available_output_bytes,
    num_bytes_queue.io.deq.valid
  )
  load_data_queue.io.enq.valid := fire_read.fire(load_data_queue.io.enq.ready)
  io.mem_stream.output_ready := fire_read.fire(io.mem_stream.output_valid)
  io.mem_stream.user_consumed_bytes := Mux(num_bytes_queue.io.deq.valid,
    chunk_size,
    0.U)
  when(fire_read.fire()){
    when(load_data_queue.io.enq.bits.is_final_chunk){
      consumed_bytes := 0.U
    }.otherwise{
      printf("Consumed bytes <= 0x%x\n", consumed_bytes + chunk_size)
      consumed_bytes := consumed_bytes + chunk_size
    }
  }
  num_bytes_queue.io.deq.ready := fire_read.fire(num_bytes_queue.io.deq.valid) &&
    load_data_queue.io.enq.bits.is_final_chunk

  // ----------------------------
  // API: connect load_data_queue
  // ----------------------------

  when (load_data_queue.io.enq.fire()) {
    printf("load_data_q:enq: sz:%x final:%x data:%x\n",
      load_data_queue.io.enq.bits.chunk_size_bytes,
      load_data_queue.io.enq.bits.is_final_chunk,
      load_data_queue.io.enq.bits.chunk_data,
    )
  }

  when (load_data_queue.io.deq.fire()) {
    printf("load_data_q:deq: sz:%x final:%x data:%x\n",
      load_data_queue.io.deq.bits.chunk_size_bytes,
      load_data_queue.io.deq.bits.is_final_chunk,
      load_data_queue.io.deq.bits.chunk_data,
    )
  }

  // 3. Write data to through the memwriter

  val store_data_queue = Module(new Queue(new LiteralChunk, 5))
  dontTouch(store_data_queue.io.count)

  val sdq_chunk_size = store_data_queue.io.deq.bits.chunk_size_bytes
  val sdq_chunk_data = store_data_queue.io.deq.bits.chunk_data
  val sdq_chunk_data_vec = VecInit(Seq.fill(l2bwBytes)(0.U(8.W)))
  for (i <- 0 to (l2bwBytes - 1)) {
    sdq_chunk_data_vec(sdq_chunk_size - 1.U - i.U) := sdq_chunk_data((8*(i+1))-1, 8*i)
  }
  io.memwrites_in.bits.data := sdq_chunk_data_vec.asUInt
  io.memwrites_in.bits.validbytes := sdq_chunk_size
  io.memwrites_in.bits.end_of_message := store_data_queue.io.deq.bits.is_final_chunk
  io.memwrites_in.valid := store_data_queue.io.deq.valid
  store_data_queue.io.deq.ready := io.memwrites_in.ready

  // -----------------------------
  // API: connect store_data_queue
  // -----------------------------

  when (store_data_queue.io.enq.fire()) {
    printf("store_data_q:enq: sz:%x final:%x data:%x\n",
      store_data_queue.io.enq.bits.chunk_size_bytes,
      store_data_queue.io.enq.bits.is_final_chunk,
      store_data_queue.io.enq.bits.chunk_data,
    )
  }

  when (store_data_queue.io.deq.fire()) {
    printf("store_data_q:deq: sz:%x final:%x data:%x\n",
      store_data_queue.io.deq.bits.chunk_size_bytes,
      store_data_queue.io.deq.bits.is_final_chunk,
      store_data_queue.io.deq.bits.chunk_data,
    )
  }
}
