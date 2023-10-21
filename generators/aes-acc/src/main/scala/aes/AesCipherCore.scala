package aes

import sys.process._

import chisel3._
import chisel3.util._
import chisel3.util.random.{LFSR}

import freechips.rocketchip.util.{DecoupledHelper}

// general resources used:
//   https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf
//   https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/hw/ip/aes/rtl/aes_core.sv
//   https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/hw/ip/aes/rtl/aes_control_fsm.sv
//   https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/hw/ip/aes/rtl/aes_reg_top.sv
//   https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/sw/device/lib/crypto/drivers/aes.c
//   https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/sw/device/lib/crypto/drivers/aes_test.c

// encrypt/decrypt 128b of data (16B) blocks with a 256b key
class aes_cipher_core extends BlackBox with HasBlackBoxPath {
  val io = IO(new Bundle {
    val clk_i = Input(Clock())
    val rst_ni = Input(Reset())

    val in_valid_i = Input(Bool())
    val in_ready_o = Output(Bool())

    val out_valid_o = Output(Bool())
    val out_ready_i = Input(Bool())

    val op_i = Input(UInt(2.W))
    val key_len_i = Input(UInt(3.W))
    val crypt_i = Input(Bool())
    val dec_key_gen_i = Input(Bool()) // decrypt key gen?
    val prng_reseed_i = Input(Bool())

    val prd_clearing_i_0 = Input(UInt(64.W))
    val prd_clearing_i_1 = Input(UInt(64.W))

    val data_in_mask_o = Output(UInt(128.W))
    val entropy_req_o = Output(Bool())
    val entropy_ack_i = Input(Bool())
    val entropy_i = Input(UInt(32.W))

    val state_init_i_0 = Input(UInt(128.W))
    val state_init_i_1 = Input(UInt(128.W))
    val key_init_i_0 = Input(UInt(256.W))
    val key_init_i_1 = Input(UInt(256.W))
    val state_o_0 = Output(UInt(128.W))
    val state_o_1 = Output(UInt(128.W))
  })

  def in_fire() = io.in_valid_i && io.in_ready_o
  def out_fire() = io.out_valid_o && io.out_ready_i

  val chipyardDir = System.getProperty("user.dir")
  val aesDir = s"$chipyardDir/generators/aes-acc/src/main/resources/vsrc/aes/aes_cipher_core"

  val proc = s"make -C $aesDir core"
  require(proc.! == 0, "Failed to run pre-processing step")

  addPath(s"$aesDir/core.sv")
}

class InCryptBundle extends Bundle {
  val encrypt = Input(Bool()) // if not then decrypt
  val data = Input(UInt(128.W))
  val key = Input(UInt(256.W))
}

class OutCryptBundle extends Bundle {
  val data = Output(UInt(128.W))
}

// ECB-mode AES-256 block driver (expects the key to stay the same throughout the entire time of an encrypt/decrypt "chain")
class AesCipherCoreDriver extends Module {
  val io = IO(new Bundle {
    val in = DecoupledIO(new InCryptBundle)
    val out = DecoupledIO(new OutCryptBundle)
  })

  object AesCipherCoreConsts {
    val AES_256 = "b100".U

    val CIPH_FWD = "b01".U
    val CIPH_INV = "b10".U
  }

  val acc = Module(new aes_cipher_core)
  acc.io.clk_i := clock
  acc.io.rst_ni := !reset.asBool

  acc.io.key_len_i := AesCipherCoreConsts.AES_256
  acc.io.entropy_ack_i := true.B // entropy is always available
  acc.io.entropy_i := LFSR(32, acc.io.entropy_req_o)
  acc.io.prd_clearing_i_0 := LFSR(64, acc.io.out_valid_o)
  acc.io.prd_clearing_i_1 := LFSR(64, acc.io.out_valid_o)

  val s_initial_idle :: s_init_reseed :: s_idle :: s_encrypt :: s_dec_key_gen :: s_decrypt :: Nil = Enum(6)
  val state = RegInit(s_initial_idle)

  switch (state) {
    // wait for core to be ready
    is (s_initial_idle) {
      when (acc.io.in_ready_o) {
        state := s_init_reseed
      }
    }

    // initially preseed the rng
    is (s_init_reseed) {
      when (acc.out_fire()) {
        state := s_idle
      }
    }

    // start here when switching from encrypt to decrypt
    is (s_idle) {
      when (io.in.valid) {
        state := Mux(io.in.bits.encrypt, s_encrypt, s_dec_key_gen)
      }
    }

    is (s_encrypt) {
      when (io.in.valid) {
        when (io.in.bits.encrypt) {
          state := s_encrypt
        } .otherwise {
          state := s_idle
        }
      } .otherwise {
        state := s_idle
      }
    }

    // create initial decryption key
    is (s_dec_key_gen) {
      when (acc.out_fire()) {
        state := s_decrypt
      }
    }

    is (s_decrypt) {
      when (io.in.valid) {
        when (!io.in.bits.encrypt) {
          state := s_decrypt
        } .otherwise {
          state := s_idle
        }
      } .otherwise {
        state := s_idle
      }
    }
  }

  // s_init_reseed:
  //   in_fire := true
  //   crypt := false
  //   prng_reseed := 1
  // s_encrypt_SEND:
  //   in_fire := true
  //   prng_reseed := 1
  //   state_init_0 := in_data ^ data_in_mask_0
  //   state_init_1 := data_in_mask_0
  // s_encrypt_RECV:
  //   out_fire := true
  //   io.out.bits.data := acc.io.state_o_1 ^ acc.io.state_o_0
  // s_dec_key_gen_SEND: // have to generate the start key for decryption before it always
  //   in_fire := true
  //   dec_key_gen := true
  //   prng_reseed := 1
  // s_dec_key_gen_RECV:
  //   out_fire := true
  // s_decrypt_SEND:
  //   in_fire := true
  //   op := decrypt
  //   prng_reseed := 1
  //   state_init_0 := in_data ^ data_in_mask_0
  //   state_init_1 := data_in_mask_0
  // s_encrypt_RECV:
  //   out_fire := true
  //   io.out.bits.data := acc.io.state_o_1 ^ acc.io.state_o_0

  val op = RegInit(AesCipherCoreConsts.CIPH_FWD)
  val prng_reseed = RegInit(false.B)
  // kinda matches how this key is setup: https://github.com/lowRISC/opentitan/blob/fe702b60582f7c4e5549352a09e7992544d41bec/sw/device/lib/crypto/drivers/aes_test.c#L67
  acc.io.key_init_i_0 := io.in.bits.key
  acc.io.key_init_i_1 := (-1).U

  val encrypt_send_helper = DecoupledHelper(
    state === s_encrypt,
    io.in.valid,
    io.in.ready
  )

  val decrypt_send_helper = DecoupledHelper(
    state === s_decrypt,
    io.in.valid,
    io.in.ready
  )

  when (io.in.fire) {
    printf(":CMDIN: Encrypt(0x%x) Data(0x%x) Key(0x%x)\n", io.in.bits.encrypt, io.in.bits.data, io.in.bits.key)
  }

  when (io.out.fire) {
    printf(":RESPOUT: Data(0x%x)\n", io.out.bits.data)
  }

  acc.io.in_valid_i := (state === s_init_reseed) || encrypt_send_helper.fire(io.in.ready) || decrypt_send_helper.fire(io.in.ready)
  io.in.ready := (acc.io.in_ready_o && state =/= s_initial_idle)

  io.out.valid := ((state === s_encrypt) || (state === s_decrypt)) && acc.io.out_valid_o
  acc.io.out_ready_i := io.out.ready || (state === s_dec_key_gen)
  io.out.bits.data := acc.io.state_o_1 ^ acc.io.state_o_0

  acc.io.crypt_i := state =/= s_init_reseed
  acc.io.prng_reseed_i := true.B // reseed as much as possible?

  acc.io.state_init_i_0 := io.in.bits.data ^ acc.io.data_in_mask_o
  acc.io.state_init_i_1 := io.in.bits.data ^ acc.io.data_in_mask_o

  acc.io.op_i := Mux(state === s_encrypt, AesCipherCoreConsts.CIPH_FWD, AesCipherCoreConsts.CIPH_INV)
}
