//package aes
//
//import chisel3._
//import chisel3.util._
//import chisel3.util.random.{LFSR}
//import chisel3.experimental.{IntParam, BaseModule}
//import org.chipsalliance.cde.config.{Field, Parameters}
//import freechips.rocketchip.subsystem.{BaseSubsystem, PeripheryBusKey}
//import freechips.rocketchip.diplomacy._
//import freechips.rocketchip.regmapper._
//import freechips.rocketchip.tilelink._

//// encrypt/decrypt 128b of data (16B) blocks with a 256b key
//class aes_cipher_core extends BlackBox with HasBlackBoxResource {
//  // TODO: fix bundle
//  val io = IO(new Bundle {
//    val clk_i = Input(Clock())
//    val rst_ni = Input(Reset())
//
//    val in_valid_i = Input(Bool())
//    val in_ready_o = Output(Bool())
//
//    val out_valid_o = Output(Bool())
//    val out_ready_i = Input(Bool())
//
//    val op_i = Input(UInt(2.W))
//    val key_len_i = Input(UInt(3.W))
//    val crypt_i = Input(Bool())
//    val dec_key_gen_i = Input(Bool()) // decrypt key gen?
//    val prng_reseed_i = Input(Bool())
//
//    val prd_clearing_i_0 = Input(UInt(64.W))
//    val prd_clearing_i_1 = Input(UInt(64.W))
//
//    val data_in_mask_o = Output(UInt(128.W))
//    val entropy_req_o = Output(Bool())
//    val entropy_ack_i = Input(Bool())
//    val entropy_i = Input(UInt(32.W))
//
//    val state_init_i_0 = Input(UInt(128.W))
//    val state_init_i_1 = Input(UInt(128.W))
//    val key_init_i_0 = Input(UInt(256.W))
//    val key_init_i_1 = Input(UInt(256.W))
//    val state_o_0 = Output(UInt(128.W))
//    val state_o_1 = Output(UInt(128.W))
//  })
//
//  def in_fire() = io.in_valid_i && io.in_ready_o
//  def out_fire() = io.out_valid_o && io.out_ready_i
//
//  addResource("/vsrc/aes_cipher_core/aes_cipher_core.sv")
//  // TODO: add more
//}
//
//object AesCipherCoreConsts {
//  val AES_256 = "b100".U
//
//  val CIPH_FWD = "b01".U
//  val CIPH_INV = "b10".U
//}

//class InCryptBundle extends Bundle {
//  val encrypt = Input(Bool()) // if not then decrypt
//  val data = Input(UInt(128.W))
//}
//
//class OutCryptBundle extends Bundle {
//  val data = Output(UInt(128.W))
//}
//
//class AesCipherCoreDriver extends Module {
//  val io = IO(new Bundle {
//    val in = DecoupledIO(new InCryptBundle)
//    val out = DecoupledIO(new OutCryptBundle)
//  })
//
//  val acc = Module(new AesCipherCore)
//  acc.io.key_len_i := AesCipherCoreConsts.AES_256
//  acc.io.out_ready_i := true.B // TODO: this TB is always high?
//  acc.io.entropy_ack_i := true.B // entropy is always available
//  acc.io.entropy_i := LFSR(32, acc.io.entropy_req_o)
//  acc.io.prd_clearing_i_0 := LFSR(64, acc.io.out_valid_o)
//  acc.io.prd_clearing_i_1 := LFSR(64, acc.io.out_valid_o)
//  val scalaRand = new scala.util.Random
//  acc.io.key_init_i_0 := (rand.nextInt()).U
//  acc.io.key_init_i_1 := (rand.nextInt()).U
//
//  val INITIAL_IDLE :: INIT_RESEED :: ENCRYPT :: DECRYPT :: Nil = Enum(8)
//  val state = RegInit(INITIAL_IDLE)
//
//  val op = RegInit(AesCipherCoreConsts.CIPH_FWD)
//  val prng_reseed = RegInit(false.B)
//
//  val reseed_helper = DecoupledHelper(
//    state === INIT_RESEED
//  )
//
//  val encrypt_helper = DecoupledHelper(
//    state === ENCRYPT,
//    io.in.valid
//  )
//
//  val decrypt_helper = DecoupledHelper(
//    state === DECRYPT,
//    io.in.valid
//  )
//
//  acc.io.in_valid_i := reseed_helper.fire() || encrypt_helper.fire() || decrypt_helper.fire() || decrypt_key_gen_helper.fire()
//  acc.io.crypt_i := !reseed_helper.fire()
//  acc.io.prng_reseed_i := true.B
//  acc.io.state_init_i_0 := io.in.bits.data ^ acc.io.data_in_mask_o
//  acc.io.state_init_i_1 := io.in.bits.data ^ acc.io.data_in_mask_o
//  acc.io.op_i := Mux(encrypt_helper.fire(), AesCipherCoreConsts.CIPH_FWD, Mux(decrypt_helper.fire(), AesCipherCoreConsts.CIPH_INV, 0.U))
//  io.out.bits.data := acc.io.state_o_1 ^ acc.io.state_o_0
//  io.out.valid := (state === ENCRYPT || state === DECRYPT) && acc.io.out_valid_o
//  io.in.ready := acc.io.in_ready_o
//
//  assert(!(encrypt_helper.fire() && decrypt_helper.fire()), "Shouldn't be able to decrypt/encrypt at same time")
//
//  // wait for core to be ready
//  when (state === INITIAL_IDLE && acc.io.in_ready_o) {
//    state := INIT_RESEED
//  }
//
//  // initially preseed the rng
//  when (state === INIT_RESEED && acc.io.out_valid_o) {
//    state := IDLE
//  }
//
//  when (state === IDLE && io.crypt.valid) {
//    state := Mux(io.crypt.bits.encrypt, ENCRYPT, DEC_KEY_GEN)
//  }
//
//  when (state === DECRYPT) {
//
//
//  }
//
//  switch(state) {
//    is(DEC_KEY_GEN) {
//      acc.io.in_valid_i := true.B
//      acc.io.dec_key_gen_i := true.B
//      acc.io.prng_reseed_i := true.B
//
//      when (acc.io.out_valid_o) {
//        state := ???
//      }
//    }
//
//    is(DECRYPT) {
//      when (acc.io.out_valid_o) {
//        val encrypted_data = acc.io.state_o_1 ^ acc.io.state_o_0
//        state := ???
//      }
//    }
//  }
//}
//
////   // DUT signals
////   sp2v_e                       in_ready, in_valid, out_valid;
////   ciph_op_e                    op;
////   key_len_e                    key_len_d, key_len_q;
////   sp2v_e                       crypt, dec_key_gen;
////   logic                        prng_reseed;
////   logic [WidthPRDClearing-1:0] prd_clearing [NumShares];
////   logic        [3:0][3:0][7:0] state_mask;
////   logic        [3:0][3:0][7:0] state_init [NumShares];
////   logic        [3:0][3:0][7:0] state_done [NumShares];
////   logic            [7:0][31:0] key_init [NumShares];
////
////   // Instantiate DUT
////   aes_cipher_core #(
////     .in_valid_i       ( in_valid            ),
////     .in_ready_o       ( in_ready            ),
////     .out_valid_o      ( out_valid           ),
////     .op_i             ( op                  ),
////     .key_len_i        ( key_len_q           ),
////     .crypt_i          ( crypt               ),
////     .dec_key_gen_i    ( dec_key_gen         ),
////     .prng_reseed_i    ( prng_reseed         ),
////     .data_in_mask_o   ( state_mask          ),
////     .state_init_i     ( state_init          ),
////     .key_init_i       ( key_init            ),
////     .state_o          ( state_done          )
////   );
////   logic                 data_in_buf_we, data_out_buf_we, check, mismatch, test_done;
////   logic [3:0][3:0][7:0] data_in_rand, data_in;
////   logic [3:0][3:0][7:0] data_out;
////   logic [3:0][3:0][7:0] data_in_buf[256];
////   logic [3:0][3:0][7:0] data_out_buf[256];
////
////   // Generate the initial state.
////   if (!SecMasking) begin : gen_state_init_no_masking
////     // Only Share 0 is used.
////     assign state_init[0] = data_in;
////
////     // Tie-off unused signals.
////     logic unused_bits;
////     assign unused_bits = ^state_mask;
////   end else begin : gen_state_init_masking
////     // Mask the input data with the mask provided by the internal masking PRNG.
////     assign state_init[0] = data_in ^ state_mask;
////     assign state_init[1] = state_mask;
////   end
////
////   always_comb begin : aes_cipher_core_tb_fsm
////     // DUT
////     in_valid    = SP2V_LOW;
////     op          = CIPH_FWD;
////     crypt       = SP2V_HIGH;
////     dec_key_gen = SP2V_LOW;
////     prng_reseed = 1'b0;
////
////     // TB
////     aes_cipher_core_tb_state_d = aes_cipher_core_tb_state_q;
////     block_count_increment      = 1'b0;
////     block_count_clear          = 1'b0;
////     key_len_d                  = key_len_q;
////     data_in_buf_we             = 1'b0;
////     data_out_buf_we            = 1'b0;
////     check                      = 1'b0;
////     test_done                  = 1'b0;
////
////     unique case (aes_cipher_core_tb_state_q)
////
////       IDLE: begin
////         // Just wait for the ciphre core to become ready.
////         if (in_ready == SP2V_HIGH) begin
////           aes_cipher_core_tb_state_d = SecMasking ? INIT_RESEED : ECB_ENCRYPT;
////         end
////       end
////
////       INIT_RESEED: begin
////         // Perform an initial reseed of the internal masking PRNG to put it into a random state.
////         in_valid    = SP2V_HIGH;
////         crypt       = SP2V_LOW;
////         prng_reseed = 1'b1;
////         if (out_valid == SP2V_HIGH) begin
////           aes_cipher_core_tb_state_d = ECB_ENCRYPT;
////         end
////       end
////
////       ECB_ENCRYPT: begin
////         // Perform encryption in parallel with a reseed of the internal masking PRNG.
////         in_valid    = SP2V_HIGH;
////         prng_reseed = 1'b1;
////         if (out_valid == SP2V_HIGH) begin
////           block_count_increment = 1'b1;
////           data_in_buf_we  = 1'b1;
////           data_out_buf_we = 1'b1;
////           // Increase the key length after every 8 blocks.
////           key_len_d = (block_count_q == 8'd7)  ? AES_192 :
////                       (block_count_q == 8'd15) ? AES_256 : key_len_q;
////           // After 24 blocks, we're starting over with decryption.
////           if (block_count_q == 8'd23) begin
////             block_count_clear          = 1'b1;
////             key_len_d                  = AES_128;
////             aes_cipher_core_tb_state_d = DEC_KEY_GEN;
////           end
////         end
////       end
////
////       DEC_KEY_GEN: begin
////         // Perform encryption in parallel with a reseed of the internal masking PRNG.
////         in_valid    = SP2V_HIGH;
////         dec_key_gen = SP2V_HIGH;
////         prng_reseed = 1'b1;
////         if (out_valid == SP2V_HIGH) begin
////           aes_cipher_core_tb_state_d = ECB_DECRYPT;
////         end
////       end
////     endcase
////   end
////
//// endmodule
