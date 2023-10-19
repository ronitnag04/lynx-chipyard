`define SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//

package entropy_src_pkg;

  //-------------------------
  // Entropy Interface
  //-------------------------

  parameter int  RNG_BUS_WIDTH   = 4;
  parameter int  CSRNG_BUS_WIDTH = 384;
  parameter int  FIPS_BUS_WIDTH  = 1;
  parameter int  FIPS_CSRNG_BUS_WIDTH = FIPS_BUS_WIDTH + CSRNG_BUS_WIDTH;
  // TODO: Should this be re-used in the RTL?
  parameter int  OBSERVE_FIFO_DEPTH = 64;


  // es entropy i/f
  typedef struct packed {
    logic es_ack;
    logic [CSRNG_BUS_WIDTH-1:0] es_bits;
    logic [FIPS_BUS_WIDTH-1:0] es_fips;
  } entropy_src_hw_if_rsp_t;

  typedef struct packed {
    logic es_req;
  } entropy_src_hw_if_req_t;

  parameter entropy_src_hw_if_req_t ENTROPY_SRC_HW_IF_REQ_DEFAULT = '{default: '0};
  parameter entropy_src_hw_if_rsp_t ENTROPY_SRC_HW_IF_RSP_DEFAULT = '{default: '0};


  // csrng block encrypt request/ack i/f
  typedef struct packed {
    logic cs_aes_halt_req;
  } cs_aes_halt_req_t;

  typedef struct packed {
    logic cs_aes_halt_ack;
  } cs_aes_halt_rsp_t;

  parameter cs_aes_halt_req_t CS_AES_HALT_REQ_DEFAULT = '{default: '0};
  parameter cs_aes_halt_rsp_t CS_AES_HALT_RSP_DEFAULT = '{default: '0};

  // ast rng i/f
  typedef struct packed {
    logic rng_enable;
  } entropy_src_rng_req_t;

  typedef struct packed {
    logic rng_valid;
    logic [RNG_BUS_WIDTH-1:0] rng_b;
  } entropy_src_rng_rsp_t;

  parameter entropy_src_rng_req_t ENTROPY_SRC_RNG_REQ_DEFAULT = '{default: '0};
  parameter entropy_src_rng_rsp_t ENTROPY_SRC_RNG_RSP_DEFAULT = '{default: '0};

  // external health test i/f
  typedef struct packed {
    logic [RNG_BUS_WIDTH-1:0] entropy_bit;
    logic entropy_bit_valid;
    logic clear;
    logic active;
    logic [15:0] thresh_hi;
    logic [15:0] thresh_lo;
    logic [15:0] health_test_window;
    logic window_wrap_pulse;
    logic threshold_scope;
  } entropy_src_xht_req_t;

  typedef struct packed {
    logic[15:0] test_cnt_hi;
    logic[15:0] test_cnt_lo;
    logic continuous_test;
    logic test_fail_hi_pulse;
    logic test_fail_lo_pulse;
  } entropy_src_xht_rsp_t;

  parameter entropy_src_xht_req_t ENTROPY_SRC_XHT_REQ_DEFAULT = '{default: '0};
  parameter entropy_src_xht_rsp_t ENTROPY_SRC_XHT_RSP_DEFAULT =
      '{test_cnt_lo: 16'hffff, default: '0};

endpackage : entropy_src_pkg
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//


package edn_pkg;
  ///////////////////////////
  // Peripheral Interfaces //
  ///////////////////////////

  parameter int unsigned   ENDPOINT_BUS_WIDTH = 32;
  parameter int unsigned   FIPS_ENDPOINT_BUS_WIDTH = entropy_src_pkg::FIPS_BUS_WIDTH +
                           ENDPOINT_BUS_WIDTH;

  // EDN request interface
  typedef struct packed {
    logic                                 edn_req;
  } edn_req_t;
  typedef struct packed {
    logic                                 edn_ack;
    logic                                 edn_fips;
    logic [ENDPOINT_BUS_WIDTH-1:0]        edn_bus;
  } edn_rsp_t;

  parameter edn_req_t EDN_REQ_DEFAULT = '0;
  parameter edn_rsp_t EDN_RSP_DEFAULT = '0;

  typedef enum logic [8:0] {
    Idle              = 9'b110000101, // idle
    BootLoadIns       = 9'b110110111, // boot: load the instantiate command
    BootLoadGen       = 9'b000000011, // boot: load the generate command
    BootInsAckWait    = 9'b011010010, // boot: wait for instantiate command ack
    BootCaptGenCnt    = 9'b010111010, // boot: capture the gen fifo count
    BootSendGenCmd    = 9'b011100100, // boot: send the generate command
    BootGenAckWait    = 9'b101101100, // boot: wait for generate command ack
    BootPulse         = 9'b100001010, // boot: signal a done pulse
    BootDone          = 9'b011011111, // boot: stay in done state until reset
    AutoLoadIns       = 9'b001110000, // auto: load the instantiate command
    AutoFirstAckWait  = 9'b001001101, // auto: wait for first instantiate command ack
    AutoAckWait       = 9'b101100011, // auto: wait for instantiate command ack
    AutoDispatch      = 9'b110101110, // auto: determine next command to be sent
    AutoCaptGenCnt    = 9'b000110101, // auto: capture the gen fifo count
    AutoSendGenCmd    = 9'b111111000, // auto: send the generate command
    AutoCaptReseedCnt = 9'b000100110, // auto: capture the reseed fifo count
    AutoSendReseedCmd = 9'b101010110, // auto: send the reseed command
    SWPortMode        = 9'b100111001, // swport: no hw request mode
    Error             = 9'b010010001  // illegal state reached and hang
  } state_e;

endpackage : edn_pkg
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


/**
 * Utility functions
 */
package caliptra_prim_util_pkg;
  /**
   * Math function: $clog2 as specified in Verilog-2005
   *
   * Do not use this function if $clog2() is available.
   *
   * clog2 =          0        for value == 0
   *         ceil(log2(value)) for value >= 1
   *
   * This implementation is a synthesizable variant of the $clog2 function as
   * specified in the Verilog-2005 standard (IEEE 1364-2005).
   *
   * To quote the standard:
   *   The system function $clog2 shall return the ceiling of the log
   *   base 2 of the argument (the log rounded up to an integer
   *   value). The argument can be an integer or an arbitrary sized
   *   vector value. The argument shall be treated as an unsigned
   *   value, and an argument value of 0 shall produce a result of 0.
   */
  function automatic integer _clog2(integer value);
    integer result;
    // Use an intermediate value to avoid assigning to an input port, which produces a warning in
    // Synopsys DC.
    integer v = value;
    v = v - 1;
    for (result = 0; v > 0; result++) begin
      v = v >> 1;
    end
    return result;
  endfunction


  /**
   * Math function: Number of bits needed to address |value| items.
   *
   *                  0        for value == 0
   * vbits =          1        for value == 1
   *         ceil(log2(value)) for value > 1
   *
   *
   * The primary use case for this function is the definition of registers/arrays
   * which are wide enough to contain |value| items.
   *
   * This function identical to $clog2() for all input values except the value 1;
   * it could be considered an "enhanced" $clog2() function.
   *
   *
   * Example 1:
   *   parameter Items = 1;
   *   localparam ItemsWidth = vbits(Items); // 1
   *   logic [ItemsWidth-1:0] item_register; // items_register is now [0:0]
   *
   * Example 2:
   *   parameter Items = 64;
   *   localparam ItemsWidth = vbits(Items); // 6
   *   logic [ItemsWidth-1:0] item_register; // items_register is now [5:0]
   *
   * Note: If you want to store the number "value" inside a register, you need
   * a register with size vbits(value + 1), since you also need to store
   * the number 0.
   *
   * Example 3:
   *   logic [vbits(64)-1:0]     store_64_logic_values; // width is [5:0]
   *   logic [vbits(64 + 1)-1:0] store_number_64;       // width is [6:0]
   */
  function automatic integer vbits(integer value);
`ifdef XCELIUM
    // The use of system functions was not allowed here in Verilog-2001, but is
    // valid since (System)Verilog-2005, which is also when $clog2() first
    // appeared.
    // Xcelium < 19.10 does not yet support the use of $clog2() here, fall back
    // to an implementation without a system function. Remove this workaround
    // if we require a newer Xcelium version.
    // See #2579 and #2597.
    return (value == 1) ? 1 : _clog2(value);
`else
    return (value == 1) ? 1 : $clog2(value);
`endif
  endfunction

`ifdef CALIPTRA_INC_ASSERT
  // Package-scoped variable to detect the end of simulation.
  //
  // Used only in DV simulations. The bit will be used by assertions in RTL to perform end-of-test
  // cleanup. It is set to 1 in `dv_test_status_pkg::dv_test_status()`, which is invoked right
  // before the simulation is terminated, to signal the status of the test.
  bit end_of_simulation;
`endif

endpackage
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Constants for use in primitives

// This file is auto-generated.

package caliptra_prim_pkg;

  // Implementation target specialization
  typedef enum integer {
    ImplGeneric,
    ImplXilinx,
    ImplBadbit
  } impl_e;
endpackage : caliptra_prim_pkg
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package caliptra_prim_sparse_fsm_pkg;
  typedef enum logic {Idle, Done} state_t;
endpackage : caliptra_prim_sparse_fsm_pkg
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// This package holds common constants and functions for PRESENT- and
// PRINCE-based scrambling devices.
//
// See also: caliptra_prim_present, caliptra_prim_prince
//
// References: - https://en.wikipedia.org/wiki/PRESENT
//             - https://en.wikipedia.org/wiki/Prince_(cipher)
//             - http://www.lightweightcrypto.org/present/present_ches2007.pdf
//             - https://eprint.iacr.org/2012/529.pdf
//             - https://eprint.iacr.org/2015/372.pdf
//             - https://eprint.iacr.org/2014/656.pdf

package caliptra_prim_cipher_pkg;

  ///////////////////
  // PRINCE Cipher //
  ///////////////////

  parameter logic [15:0][3:0] PRINCE_SBOX4 = {4'h4, 4'hD, 4'h5, 4'hE,
                                              4'h0, 4'h8, 4'h7, 4'h6,
                                              4'h1, 4'h9, 4'hC, 4'hA,
                                              4'h2, 4'h3, 4'hF, 4'hB};

  parameter logic [15:0][3:0] PRINCE_SBOX4_INV = {4'h1, 4'hC, 4'hE, 4'h5,
                                                  4'h0, 4'h4, 4'h6, 4'hA,
                                                  4'h9, 4'h8, 4'hD, 4'hF,
                                                  4'h2, 4'h3, 4'h7, 4'hB};
  // nibble permutations
  parameter logic [15:0][3:0] PRINCE_SHIFT_ROWS64  = '{4'hF, 4'hA, 4'h5, 4'h0,
                                                       4'hB, 4'h6, 4'h1, 4'hC,
                                                       4'h7, 4'h2, 4'hD, 4'h8,
                                                       4'h3, 4'hE, 4'h9, 4'h4};

  parameter logic [15:0][3:0] PRINCE_SHIFT_ROWS64_INV = '{4'hF, 4'h2, 4'h5, 4'h8,
                                                          4'hB, 4'hE, 4'h1, 4'h4,
                                                          4'h7, 4'hA, 4'hD, 4'h0,
                                                          4'h3, 4'h6, 4'h9, 4'hC};

  // these are the round constants
  parameter logic [11:0][63:0] PRINCE_ROUND_CONST = {64'hC0AC29B7C97C50DD,
                                                     64'hD3B5A399CA0C2399,
                                                     64'h64A51195E0E3610D,
                                                     64'hC882D32F25323C54,
                                                     64'h85840851F1AC43AA,
                                                     64'h7EF84F78FD955CB1,
                                                     64'hBE5466CF34E90C6C,
                                                     64'h452821E638D01377,
                                                     64'h082EFA98EC4E6C89,
                                                     64'hA4093822299F31D0,
                                                     64'h13198A2E03707344,
                                                     64'h0000000000000000};

  // tweak constant for key modification between enc/dec modes
  parameter logic [63:0] PRINCE_ALPHA_CONST = 64'hC0AC29B7C97C50DD;

  // masking constants for shift rows function below
  parameter logic [15:0] PRINCE_SHIFT_ROWS_CONST0 = 16'h7BDE;
  parameter logic [15:0] PRINCE_SHIFT_ROWS_CONST1 = 16'hBDE7;
  parameter logic [15:0] PRINCE_SHIFT_ROWS_CONST2 = 16'hDE7B;
  parameter logic [15:0] PRINCE_SHIFT_ROWS_CONST3 = 16'hE7BD;

  // nibble shifts
  function automatic logic [31:0] prince_shiftrows_32bit(logic [31:0]      state_in,
                                                         logic [15:0][3:0] shifts );
    logic [31:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 32/2; k++) begin
      // operate on pairs of 2bit instead of nibbles
      state_out[k*2  +: 2] = state_in[shifts[k]*2  +: 2];
    end
    return state_out;
  endfunction : prince_shiftrows_32bit

  function automatic logic [63:0] prince_shiftrows_64bit(logic [63:0]      state_in,
                                                         logic [15:0][3:0] shifts );
    logic [63:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 64/4; k++) begin
      state_out[k*4  +: 4] = state_in[shifts[k]*4  +: 4];
    end
    return state_out;
  endfunction : prince_shiftrows_64bit

  // XOR reduction of four nibbles in a 16bit subvector
  function automatic logic [3:0] prince_nibble_red16(logic [15:0] vect);
    return vect[0 +: 4] ^ vect[4 +: 4] ^ vect[8 +: 4] ^ vect[12 +: 4];
  endfunction : prince_nibble_red16

  // M prime multiplication
  function automatic logic [31:0] prince_mult_prime_32bit(logic [31:0] state_in);
    logic [31:0] state_out;
    // M0
    state_out[0  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[4  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[8  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    state_out[12 +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    // M1
    state_out[16 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    state_out[20 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[24 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[28 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    return state_out;
  endfunction : prince_mult_prime_32bit

  // M prime multiplication
  function automatic logic [63:0] prince_mult_prime_64bit(logic [63:0] state_in);
    logic [63:0] state_out;
    // M0
    state_out[0  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[4  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[8  +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    state_out[12 +: 4] = prince_nibble_red16(state_in[ 0 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    // M1
    state_out[16 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    state_out[20 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[24 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[28 +: 4] = prince_nibble_red16(state_in[16 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    // M1
    state_out[32 +: 4] = prince_nibble_red16(state_in[32 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    state_out[36 +: 4] = prince_nibble_red16(state_in[32 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[40 +: 4] = prince_nibble_red16(state_in[32 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[44 +: 4] = prince_nibble_red16(state_in[32 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    // M0
    state_out[48 +: 4] = prince_nibble_red16(state_in[48 +: 16] & PRINCE_SHIFT_ROWS_CONST3);
    state_out[52 +: 4] = prince_nibble_red16(state_in[48 +: 16] & PRINCE_SHIFT_ROWS_CONST2);
    state_out[56 +: 4] = prince_nibble_red16(state_in[48 +: 16] & PRINCE_SHIFT_ROWS_CONST1);
    state_out[60 +: 4] = prince_nibble_red16(state_in[48 +: 16] & PRINCE_SHIFT_ROWS_CONST0);
    return state_out;
  endfunction : prince_mult_prime_64bit


  ////////////////////
  // PRESENT Cipher //
  ////////////////////

  // this is the sbox from the present cipher
  parameter logic [15:0][3:0] PRESENT_SBOX4 = {4'h2, 4'h1, 4'h7, 4'h4,
                                               4'h8, 4'hF, 4'hE, 4'h3,
                                               4'hD, 4'hA, 4'h0, 4'h9,
                                               4'hB, 4'h6, 4'h5, 4'hC};

  parameter logic [15:0][3:0] PRESENT_SBOX4_INV = {4'hA, 4'h9, 4'h7, 4'h0,
                                                   4'h3, 4'h6, 4'h4, 4'hB,
                                                   4'hD, 4'h2, 4'h1, 4'hC,
                                                   4'h8, 4'hF, 4'hE, 4'h5};

  // these are modified permutation indices for a 32bit version that
  // follow the same pattern as for the 64bit version
  parameter logic [31:0][4:0] PRESENT_PERM32 = {5'd31, 5'd23, 5'd15, 5'd07,
                                                5'd30, 5'd22, 5'd14, 5'd06,
                                                5'd29, 5'd21, 5'd13, 5'd05,
                                                5'd28, 5'd20, 5'd12, 5'd04,
                                                5'd27, 5'd19, 5'd11, 5'd03,
                                                5'd26, 5'd18, 5'd10, 5'd02,
                                                5'd25, 5'd17, 5'd09, 5'd01,
                                                5'd24, 5'd16, 5'd08, 5'd00};

  parameter logic [31:0][4:0] PRESENT_PERM32_INV = {5'd31, 5'd27, 5'd23, 5'd19,
                                                    5'd15, 5'd11, 5'd07, 5'd03,
                                                    5'd30, 5'd26, 5'd22, 5'd18,
                                                    5'd14, 5'd10, 5'd06, 5'd02,
                                                    5'd29, 5'd25, 5'd21, 5'd17,
                                                    5'd13, 5'd09, 5'd05, 5'd01,
                                                    5'd28, 5'd24, 5'd20, 5'd16,
                                                    5'd12, 5'd08, 5'd04, 5'd00};

  // these are the permutation indices of the present cipher
  parameter logic [63:0][5:0] PRESENT_PERM64 = {6'd63, 6'd47, 6'd31, 6'd15,
                                                6'd62, 6'd46, 6'd30, 6'd14,
                                                6'd61, 6'd45, 6'd29, 6'd13,
                                                6'd60, 6'd44, 6'd28, 6'd12,
                                                6'd59, 6'd43, 6'd27, 6'd11,
                                                6'd58, 6'd42, 6'd26, 6'd10,
                                                6'd57, 6'd41, 6'd25, 6'd09,
                                                6'd56, 6'd40, 6'd24, 6'd08,
                                                6'd55, 6'd39, 6'd23, 6'd07,
                                                6'd54, 6'd38, 6'd22, 6'd06,
                                                6'd53, 6'd37, 6'd21, 6'd05,
                                                6'd52, 6'd36, 6'd20, 6'd04,
                                                6'd51, 6'd35, 6'd19, 6'd03,
                                                6'd50, 6'd34, 6'd18, 6'd02,
                                                6'd49, 6'd33, 6'd17, 6'd01,
                                                6'd48, 6'd32, 6'd16, 6'd00};

  parameter logic [63:0][5:0] PRESENT_PERM64_INV = {6'd63, 6'd59, 6'd55, 6'd51,
                                                    6'd47, 6'd43, 6'd39, 6'd35,
                                                    6'd31, 6'd27, 6'd23, 6'd19,
                                                    6'd15, 6'd11, 6'd07, 6'd03,
                                                    6'd62, 6'd58, 6'd54, 6'd50,
                                                    6'd46, 6'd42, 6'd38, 6'd34,
                                                    6'd30, 6'd26, 6'd22, 6'd18,
                                                    6'd14, 6'd10, 6'd06, 6'd02,
                                                    6'd61, 6'd57, 6'd53, 6'd49,
                                                    6'd45, 6'd41, 6'd37, 6'd33,
                                                    6'd29, 6'd25, 6'd21, 6'd17,
                                                    6'd13, 6'd09, 6'd05, 6'd01,
                                                    6'd60, 6'd56, 6'd52, 6'd48,
                                                    6'd44, 6'd40, 6'd36, 6'd32,
                                                    6'd28, 6'd24, 6'd20, 6'd16,
                                                    6'd12, 6'd08, 6'd04, 6'd00};

  // forward key schedule
  function automatic logic [63:0] present_update_key64(logic [63:0] key_in,
                                                       logic [4:0]  round_idx);
    logic [63:0] key_out;
    // rotate by 61 to the left
    key_out = {key_in[63-61:0], key_in[63:64-61]};
    // sbox on uppermost 4 bits
    key_out[63 -: 4] = PRESENT_SBOX4[key_out[63 -: 4]];
    // xor in round counter on bits 19 to 15
    key_out[19:15] ^= round_idx;
    return key_out;
  endfunction : present_update_key64

  function automatic logic [79:0] present_update_key80(logic [79:0] key_in,
                                                       logic [4:0]  round_idx);
    logic [79:0] key_out;
    // rotate by 61 to the left
    key_out = {key_in[79-61:0], key_in[79:80-61]};
    // sbox on uppermost 4 bits
    key_out[79 -: 4] = PRESENT_SBOX4[key_out[79 -: 4]];
    // xor in round counter on bits 19 to 15
    key_out[19:15] ^= round_idx;
    return key_out;
  endfunction : present_update_key80

  function automatic logic [127:0] present_update_key128(logic [127:0] key_in,
                                                         logic [4:0]   round_idx);
    logic [127:0] key_out;
    // rotate by 61 to the left
    key_out = {key_in[127-61:0], key_in[127:128-61]};
    // sbox on uppermost 4 bits
    key_out[127 -: 4] = PRESENT_SBOX4[key_out[127 -: 4]];
    // sbox on second nibble from top
    key_out[123 -: 4] = PRESENT_SBOX4[key_out[123 -: 4]];
    // xor in round counter on bits 66 to 62
    key_out[66:62] ^= round_idx;
    return key_out;
  endfunction : present_update_key128


  // inverse key schedule
  function automatic logic [63:0] present_inv_update_key64(logic [63:0] key_in,
                                                           logic [4:0]  round_idx);
    logic [63:0] key_out = key_in;
    // xor in round counter on bits 19 to 15
    key_out[19:15] ^= round_idx;
    // sbox on uppermost 4 bits
    key_out[63 -: 4] = PRESENT_SBOX4_INV[key_out[63 -: 4]];
    // rotate by 61 to the right
    key_out = {key_out[60:0], key_out[63:61]};
    return key_out;
  endfunction : present_inv_update_key64

  function automatic logic [79:0] present_inv_update_key80(logic [79:0] key_in,
                                                           logic [4:0]  round_idx);
    logic [79:0] key_out = key_in;
    // xor in round counter on bits 19 to 15
    key_out[19:15] ^= round_idx;
    // sbox on uppermost 4 bits
    key_out[79 -: 4] = PRESENT_SBOX4_INV[key_out[79 -: 4]];
    // rotate by 61 to the right
    key_out = {key_out[60:0], key_out[79:61]};
    return key_out;
  endfunction : present_inv_update_key80

  function automatic logic [127:0] present_inv_update_key128(logic [127:0] key_in,
                                                             logic [4:0]   round_idx);
    logic [127:0] key_out = key_in;
    // xor in round counter on bits 66 to 62
    key_out[66:62] ^= round_idx;
    // sbox on second highest nibble
    key_out[123 -: 4] = PRESENT_SBOX4_INV[key_out[123 -: 4]];
    // sbox on uppermost 4 bits
    key_out[127 -: 4] = PRESENT_SBOX4_INV[key_out[127 -: 4]];
    // rotate by 61 to the right
    key_out = {key_out[60:0], key_out[127:61]};
    return key_out;
  endfunction : present_inv_update_key128


  // these functions can be used to derive the DEC key from the ENC key by
  // stepping the key by the correct number of rounds using the keyschedule functions above.
  function automatic logic [63:0] present_get_dec_key64(logic [63:0] key_in,
                                                        // total number of rounds employed
                                                        logic [4:0]  round_cnt);
    logic [63:0] key_out;
    key_out = key_in;
    for (int unsigned k = 0; k < round_cnt; k++) begin
      key_out = present_update_key64(key_out, 5'(k + 1));
    end
    return key_out;
  endfunction : present_get_dec_key64

  function automatic logic [79:0] present_get_dec_key80(logic [79:0] key_in,
                                                        // total number of rounds employed
                                                        logic [4:0]  round_cnt);
    logic [79:0] key_out;
    key_out = key_in;
    for (int unsigned k = 0; k < round_cnt; k++) begin
      key_out = present_update_key80(key_out, 5'(k + 1));
    end
    return key_out;
  endfunction : present_get_dec_key80

  function automatic logic [127:0] present_get_dec_key128(logic [127:0] key_in,
                                                          // total number of rounds employed
                                                          logic [4:0]   round_cnt);
    logic [127:0] key_out;
    key_out = key_in;
    for (int unsigned k = 0; k < round_cnt; k++) begin
      key_out = present_update_key128(key_out, 5'(k + 1));
    end
    return key_out;
  endfunction : present_get_dec_key128

  /////////////////////////
  // Common Subfunctions //
  /////////////////////////

  function automatic logic [7:0] sbox4_8bit(logic [7:0] state_in, logic [15:0][3:0] sbox4);
    logic [7:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 8/4; k++) begin
      state_out[k*4  +: 4] = sbox4[state_in[k*4  +: 4]];
    end
    return state_out;
  endfunction : sbox4_8bit

  function automatic logic [15:0] sbox4_16bit(logic [15:0] state_in, logic [15:0][3:0] sbox4);
    logic [15:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 2; k++) begin
      state_out[k*8  +: 8] = sbox4_8bit(state_in[k*8  +: 8], sbox4);
    end
    return state_out;
  endfunction : sbox4_16bit

  function automatic logic [31:0] sbox4_32bit(logic [31:0] state_in, logic [15:0][3:0] sbox4);
    logic [31:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 4; k++) begin
      state_out[k*8  +: 8] = sbox4_8bit(state_in[k*8  +: 8], sbox4);
    end
    return state_out;
  endfunction : sbox4_32bit

  function automatic logic [63:0] sbox4_64bit(logic [63:0] state_in, logic [15:0][3:0] sbox4);
    logic [63:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 8; k++) begin
      state_out[k*8  +: 8] = sbox4_8bit(state_in[k*8  +: 8], sbox4);
    end
    return state_out;
  endfunction : sbox4_64bit

  function automatic logic [7:0] perm_8bit(logic [7:0] state_in, logic [7:0][2:0] perm);
    logic [7:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 8; k++) begin
      state_out[perm[k]] = state_in[k];
    end
    return state_out;
  endfunction : perm_8bit

    function automatic logic [15:0] perm_16bit(logic [15:0] state_in, logic [15:0][3:0] perm);
    logic [15:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 16; k++) begin
      state_out[perm[k]] = state_in[k];
    end
    return state_out;
  endfunction : perm_16bit

  function automatic logic [31:0] perm_32bit(logic [31:0] state_in, logic [31:0][4:0] perm);
    logic [31:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 32; k++) begin
      state_out[perm[k]] = state_in[k];
    end
    return state_out;
  endfunction : perm_32bit

  function automatic logic [63:0] perm_64bit(logic [63:0] state_in, logic [63:0][5:0] perm);
    logic [63:0] state_out;
    // note that if simulation performance becomes an issue, this loop can be unrolled
    for (int k = 0; k < 64; k++) begin
      state_out[perm[k]] = state_in[k];
    end
    return state_out;
  endfunction : perm_64bit

endpackage : caliptra_prim_cipher_pkg
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package aes_reg_pkg;

  // Param list
  parameter int NumRegsKey = 8;
  parameter int NumRegsIv = 4;
  parameter int NumRegsData = 4;
  parameter int NumAlerts = 2;

  // Address widths within the block
  parameter int BlockAw = 8;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    struct packed {
      logic        q;
      logic        qe;
    } recov_ctrl_update_err;
    struct packed {
      logic        q;
      logic        qe;
    } fatal_fault;
  } aes_reg2hw_alert_test_reg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } aes_reg2hw_key_share0_mreg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } aes_reg2hw_key_share1_mreg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } aes_reg2hw_iv_mreg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } aes_reg2hw_data_in_mreg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        re;
  } aes_reg2hw_data_out_mreg_t;

  typedef struct packed {
    struct packed {
      logic [1:0]  q;
      logic        qe;
      logic        re;
    } operation;
    struct packed {
      logic [5:0]  q;
      logic        qe;
      logic        re;
    } mode;
    struct packed {
      logic [2:0]  q;
      logic        qe;
      logic        re;
    } key_len;
    struct packed {
      logic        q;
      logic        qe;
      logic        re;
    } sideload;
    struct packed {
      logic [2:0]  q;
      logic        qe;
      logic        re;
    } prng_reseed_rate;
    struct packed {
      logic        q;
      logic        qe;
      logic        re;
    } manual_operation;
  } aes_reg2hw_ctrl_shadowed_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } key_touch_forces_reseed;
    struct packed {
      logic        q;
    } force_masks;
  } aes_reg2hw_ctrl_aux_shadowed_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } start;
    struct packed {
      logic        q;
    } key_iv_data_in_clear;
    struct packed {
      logic        q;
    } data_out_clear;
    struct packed {
      logic        q;
    } prng_reseed;
  } aes_reg2hw_trigger_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } idle;
    struct packed {
      logic        q;
    } output_lost;
  } aes_reg2hw_status_reg_t;

  typedef struct packed {
    logic [31:0] d;
  } aes_hw2reg_key_share0_mreg_t;

  typedef struct packed {
    logic [31:0] d;
  } aes_hw2reg_key_share1_mreg_t;

  typedef struct packed {
    logic [31:0] d;
  } aes_hw2reg_iv_mreg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } aes_hw2reg_data_in_mreg_t;

  typedef struct packed {
    logic [31:0] d;
  } aes_hw2reg_data_out_mreg_t;

  typedef struct packed {
    struct packed {
      logic [1:0]  d;
    } operation;
    struct packed {
      logic [5:0]  d;
    } mode;
    struct packed {
      logic [2:0]  d;
    } key_len;
    struct packed {
      logic        d;
    } sideload;
    struct packed {
      logic [2:0]  d;
    } prng_reseed_rate;
    struct packed {
      logic        d;
    } manual_operation;
  } aes_hw2reg_ctrl_shadowed_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } start;
    struct packed {
      logic        d;
      logic        de;
    } key_iv_data_in_clear;
    struct packed {
      logic        d;
      logic        de;
    } data_out_clear;
    struct packed {
      logic        d;
      logic        de;
    } prng_reseed;
  } aes_hw2reg_trigger_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } idle;
    struct packed {
      logic        d;
      logic        de;
    } stall;
    struct packed {
      logic        d;
      logic        de;
    } output_lost;
    struct packed {
      logic        d;
      logic        de;
    } output_valid;
    struct packed {
      logic        d;
      logic        de;
    } input_ready;
    struct packed {
      logic        d;
      logic        de;
    } alert_recov_ctrl_update_err;
    struct packed {
      logic        d;
      logic        de;
    } alert_fatal_fault;
  } aes_hw2reg_status_reg_t;

  // Register -> HW type
  typedef struct packed {
    aes_reg2hw_alert_test_reg_t alert_test; // [957:954]
    aes_reg2hw_key_share0_mreg_t [7:0] key_share0; // [953:690]
    aes_reg2hw_key_share1_mreg_t [7:0] key_share1; // [689:426]
    aes_reg2hw_iv_mreg_t [3:0] iv; // [425:294]
    aes_reg2hw_data_in_mreg_t [3:0] data_in; // [293:162]
    aes_reg2hw_data_out_mreg_t [3:0] data_out; // [161:30]
    aes_reg2hw_ctrl_shadowed_reg_t ctrl_shadowed; // [29:8]
    aes_reg2hw_ctrl_aux_shadowed_reg_t ctrl_aux_shadowed; // [7:6]
    aes_reg2hw_trigger_reg_t trigger; // [5:2]
    aes_reg2hw_status_reg_t status; // [1:0]
  } aes_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    aes_hw2reg_key_share0_mreg_t [7:0] key_share0; // [937:682]
    aes_hw2reg_key_share1_mreg_t [7:0] key_share1; // [681:426]
    aes_hw2reg_iv_mreg_t [3:0] iv; // [425:298]
    aes_hw2reg_data_in_mreg_t [3:0] data_in; // [297:166]
    aes_hw2reg_data_out_mreg_t [3:0] data_out; // [165:38]
    aes_hw2reg_ctrl_shadowed_reg_t ctrl_shadowed; // [37:22]
    aes_hw2reg_trigger_reg_t trigger; // [21:14]
    aes_hw2reg_status_reg_t status; // [13:0]
  } aes_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] AES_ALERT_TEST_OFFSET = 8'h 0;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_0_OFFSET = 8'h 4;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_1_OFFSET = 8'h 8;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_2_OFFSET = 8'h c;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_3_OFFSET = 8'h 10;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_4_OFFSET = 8'h 14;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_5_OFFSET = 8'h 18;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_6_OFFSET = 8'h 1c;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE0_7_OFFSET = 8'h 20;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_0_OFFSET = 8'h 24;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_1_OFFSET = 8'h 28;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_2_OFFSET = 8'h 2c;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_3_OFFSET = 8'h 30;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_4_OFFSET = 8'h 34;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_5_OFFSET = 8'h 38;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_6_OFFSET = 8'h 3c;
  parameter logic [BlockAw-1:0] AES_KEY_SHARE1_7_OFFSET = 8'h 40;
  parameter logic [BlockAw-1:0] AES_IV_0_OFFSET = 8'h 44;
  parameter logic [BlockAw-1:0] AES_IV_1_OFFSET = 8'h 48;
  parameter logic [BlockAw-1:0] AES_IV_2_OFFSET = 8'h 4c;
  parameter logic [BlockAw-1:0] AES_IV_3_OFFSET = 8'h 50;
  parameter logic [BlockAw-1:0] AES_DATA_IN_0_OFFSET = 8'h 54;
  parameter logic [BlockAw-1:0] AES_DATA_IN_1_OFFSET = 8'h 58;
  parameter logic [BlockAw-1:0] AES_DATA_IN_2_OFFSET = 8'h 5c;
  parameter logic [BlockAw-1:0] AES_DATA_IN_3_OFFSET = 8'h 60;
  parameter logic [BlockAw-1:0] AES_DATA_OUT_0_OFFSET = 8'h 64;
  parameter logic [BlockAw-1:0] AES_DATA_OUT_1_OFFSET = 8'h 68;
  parameter logic [BlockAw-1:0] AES_DATA_OUT_2_OFFSET = 8'h 6c;
  parameter logic [BlockAw-1:0] AES_DATA_OUT_3_OFFSET = 8'h 70;
  parameter logic [BlockAw-1:0] AES_CTRL_SHADOWED_OFFSET = 8'h 74;
  parameter logic [BlockAw-1:0] AES_CTRL_AUX_SHADOWED_OFFSET = 8'h 78;
  parameter logic [BlockAw-1:0] AES_CTRL_AUX_REGWEN_OFFSET = 8'h 7c;
  parameter logic [BlockAw-1:0] AES_TRIGGER_OFFSET = 8'h 80;
  parameter logic [BlockAw-1:0] AES_STATUS_OFFSET = 8'h 84;

  // Reset values for hwext registers and their fields
  parameter logic [1:0] AES_ALERT_TEST_RESVAL = 2'h 0;
  parameter logic [0:0] AES_ALERT_TEST_RECOV_CTRL_UPDATE_ERR_RESVAL = 1'h 0;
  parameter logic [0:0] AES_ALERT_TEST_FATAL_FAULT_RESVAL = 1'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_0_KEY_SHARE0_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_1_KEY_SHARE0_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_2_KEY_SHARE0_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_3_KEY_SHARE0_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_4_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_4_KEY_SHARE0_4_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_5_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_5_KEY_SHARE0_5_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_6_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_6_KEY_SHARE0_6_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_7_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE0_7_KEY_SHARE0_7_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_0_KEY_SHARE1_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_1_KEY_SHARE1_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_2_KEY_SHARE1_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_3_KEY_SHARE1_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_4_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_4_KEY_SHARE1_4_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_5_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_5_KEY_SHARE1_5_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_6_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_6_KEY_SHARE1_6_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_7_RESVAL = 32'h 0;
  parameter logic [31:0] AES_KEY_SHARE1_7_KEY_SHARE1_7_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_0_IV_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_1_IV_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_2_IV_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_IV_3_IV_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_0_DATA_OUT_0_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_1_DATA_OUT_1_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_2_DATA_OUT_2_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_3_RESVAL = 32'h 0;
  parameter logic [31:0] AES_DATA_OUT_3_DATA_OUT_3_RESVAL = 32'h 0;
  parameter logic [15:0] AES_CTRL_SHADOWED_RESVAL = 16'h 1181;
  parameter logic [1:0] AES_CTRL_SHADOWED_OPERATION_RESVAL = 2'h 1;
  parameter logic [5:0] AES_CTRL_SHADOWED_MODE_RESVAL = 6'h 20;
  parameter logic [2:0] AES_CTRL_SHADOWED_KEY_LEN_RESVAL = 3'h 1;
  parameter logic [0:0] AES_CTRL_SHADOWED_SIDELOAD_RESVAL = 1'h 0;
  parameter logic [2:0] AES_CTRL_SHADOWED_PRNG_RESEED_RATE_RESVAL = 3'h 1;
  parameter logic [0:0] AES_CTRL_SHADOWED_MANUAL_OPERATION_RESVAL = 1'h 0;

  // Register index
  typedef enum int {
    AES_ALERT_TEST,
    AES_KEY_SHARE0_0,
    AES_KEY_SHARE0_1,
    AES_KEY_SHARE0_2,
    AES_KEY_SHARE0_3,
    AES_KEY_SHARE0_4,
    AES_KEY_SHARE0_5,
    AES_KEY_SHARE0_6,
    AES_KEY_SHARE0_7,
    AES_KEY_SHARE1_0,
    AES_KEY_SHARE1_1,
    AES_KEY_SHARE1_2,
    AES_KEY_SHARE1_3,
    AES_KEY_SHARE1_4,
    AES_KEY_SHARE1_5,
    AES_KEY_SHARE1_6,
    AES_KEY_SHARE1_7,
    AES_IV_0,
    AES_IV_1,
    AES_IV_2,
    AES_IV_3,
    AES_DATA_IN_0,
    AES_DATA_IN_1,
    AES_DATA_IN_2,
    AES_DATA_IN_3,
    AES_DATA_OUT_0,
    AES_DATA_OUT_1,
    AES_DATA_OUT_2,
    AES_DATA_OUT_3,
    AES_CTRL_SHADOWED,
    AES_CTRL_AUX_SHADOWED,
    AES_CTRL_AUX_REGWEN,
    AES_TRIGGER,
    AES_STATUS
  } aes_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] AES_PERMIT [34] = '{
    4'b 0001, // index[ 0] AES_ALERT_TEST
    4'b 1111, // index[ 1] AES_KEY_SHARE0_0
    4'b 1111, // index[ 2] AES_KEY_SHARE0_1
    4'b 1111, // index[ 3] AES_KEY_SHARE0_2
    4'b 1111, // index[ 4] AES_KEY_SHARE0_3
    4'b 1111, // index[ 5] AES_KEY_SHARE0_4
    4'b 1111, // index[ 6] AES_KEY_SHARE0_5
    4'b 1111, // index[ 7] AES_KEY_SHARE0_6
    4'b 1111, // index[ 8] AES_KEY_SHARE0_7
    4'b 1111, // index[ 9] AES_KEY_SHARE1_0
    4'b 1111, // index[10] AES_KEY_SHARE1_1
    4'b 1111, // index[11] AES_KEY_SHARE1_2
    4'b 1111, // index[12] AES_KEY_SHARE1_3
    4'b 1111, // index[13] AES_KEY_SHARE1_4
    4'b 1111, // index[14] AES_KEY_SHARE1_5
    4'b 1111, // index[15] AES_KEY_SHARE1_6
    4'b 1111, // index[16] AES_KEY_SHARE1_7
    4'b 1111, // index[17] AES_IV_0
    4'b 1111, // index[18] AES_IV_1
    4'b 1111, // index[19] AES_IV_2
    4'b 1111, // index[20] AES_IV_3
    4'b 1111, // index[21] AES_DATA_IN_0
    4'b 1111, // index[22] AES_DATA_IN_1
    4'b 1111, // index[23] AES_DATA_IN_2
    4'b 1111, // index[24] AES_DATA_IN_3
    4'b 1111, // index[25] AES_DATA_OUT_0
    4'b 1111, // index[26] AES_DATA_OUT_1
    4'b 1111, // index[27] AES_DATA_OUT_2
    4'b 1111, // index[28] AES_DATA_OUT_3
    4'b 0011, // index[29] AES_CTRL_SHADOWED
    4'b 0001, // index[30] AES_CTRL_AUX_SHADOWED
    4'b 0001, // index[31] AES_CTRL_AUX_REGWEN
    4'b 0001, // index[32] AES_TRIGGER
    4'b 0001  // index[33] AES_STATUS
  };

endpackage
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES package

package aes_pkg;

// If this parameter is set, fatal alerts clear all status and trigger bits to zero. By
// default, it's not set, i.e., no clearing is happening, in order to simplify debugging.
parameter bit ClearStatusOnFatalAlert = 1'b0;

// The initial key is always provided in two shares, independently whether the cipher core is
// masked or not.
parameter int unsigned NumSharesKey = 2;

// Software updates IV in chunks of 32 bits, the counter updates 16 bits at a time.
parameter int unsigned SliceSizeCtr = 16;
parameter int unsigned NumSlicesCtr = aes_reg_pkg::NumRegsIv * 32 / SliceSizeCtr;
parameter int unsigned SliceIdxWidth = caliptra_prim_util_pkg::vbits(NumSlicesCtr);

// Widths of signals carrying pseudo-random data for clearing
parameter int unsigned WidthPRDClearing = 64;
parameter int unsigned NumChunksPRDClearing128 = 128/WidthPRDClearing;
parameter int unsigned NumChunksPRDClearing256 = 256/WidthPRDClearing;

// Widths of signals carrying pseudo-random data for masking
parameter int unsigned WidthPRDSBox     = 8;  // Number PRD bits per S-Box. This includes the
                                              // 8 bits for the output mask when using any of the
                                              // masked Canright S-Box implementations.
parameter int unsigned WidthPRDData     = 16*WidthPRDSBox; // 16 S-Boxes for the data path
parameter int unsigned WidthPRDKey      = 4*WidthPRDSBox;  // 4 S-Boxes for the key expand
parameter int unsigned WidthPRDMasking  = WidthPRDData + WidthPRDKey;

parameter int unsigned ChunkSizePRDMasking = WidthPRDMasking/5;

// Clearing PRNG default LFSR seed and permutation
// These LFSR parameters have been generated with
// $ util/design/gen-lfsr-seed.py --width 64 --seed 31468618 --prefix "Clearing"
parameter int ClearingLfsrWidth = 64;
typedef logic [ClearingLfsrWidth-1:0] clearing_lfsr_seed_t;
typedef logic [ClearingLfsrWidth-1:0][$clog2(ClearingLfsrWidth)-1:0] clearing_lfsr_perm_t;
parameter clearing_lfsr_seed_t RndCnstClearingLfsrSeedDefault = 64'hc32d580f74f1713a;
parameter clearing_lfsr_perm_t RndCnstClearingLfsrPermDefault = {
  128'hb33fdfc81deb6292c21f8a3102585067,
  256'h9c2f4be1bbe937b4b7c9d7f4e57568d99c8ae291a899143e0d8459d31b143223
};
// A second permutation is needed for the second share.
parameter clearing_lfsr_perm_t RndCnstClearingSharePermDefault = {
  128'hf66fd61b27847edc2286706fb3a2e900,
  256'h9736b95ac3f3b5205caf8dc536aad73605d393c8dd94476e830e97891d4828d0
};

// Masking PRNG default LFSR seed and permutation
// We use a single seed that is split down into chunks internally.
// These LFSR parameters have been generated with
// $ util/design/gen-lfsr-seed.py --width 160 --seed 31468618 --prefix "Masking"
parameter int MaskingLfsrWidth = 160; // = WidthPRDMasking = WidthPRDSBox * (16 + 4)
typedef logic [MaskingLfsrWidth-1:0] masking_lfsr_seed_t;
typedef logic [MaskingLfsrWidth-1:0][$clog2(MaskingLfsrWidth)-1:0] masking_lfsr_perm_t;
parameter masking_lfsr_seed_t RndCnstMaskingLfsrSeedDefault =
  160'hc132b5723c5a4cf4743b3c7c32d580f74f1713a;
parameter masking_lfsr_perm_t RndCnstMaskingLfsrPermDefault = {
  256'h17261943423e4c5c03872194050c7e5f8497081d96666d406f4b606473303469,
  256'h8e7c721c8832471f59919e0b128f067b25622768462e554d8970815d490d7f44,
  256'h048c867d907a239b20220f6c79071a852d76485452189f14091b1e744e396737,
  256'h4f785b772b352f6550613c58130a8b104a3f28019c9a380233956b00563a512c,
  256'h808d419d63982a16995e0e3b57826a36718a9329452492533d83115a75316e15
};

typedef enum integer {
  SBoxImplLut,                   // Unmasked LUT-based S-Box
  SBoxImplCanright,              // Unmasked Canright S-Box, see aes_sbox_canright.sv
  SBoxImplCanrightMasked,        // First-order masked Canright S-Box
                                 // see aes_sbox_canright_masked.sv
  SBoxImplCanrightMaskedNoreuse, // First-order masked Canright S-Box without mask reuse,
                                 // see aes_sbox_canright_masked_noreuse.sv
  SBoxImplDom                    // First-order masked S-Box using domain-oriented masking,
                                 // see aes_sbox_canright_dom.sv
} sbox_impl_e;


// Parameters used for controlgroups in the coverage
parameter int AES_OP_WIDTH             = 2;
parameter int AES_MODE_WIDTH           = 6;
parameter int AES_KEYLEN_WIDTH         = 3;
parameter int AES_PRNGRESEEDRATE_WIDTH = 3;

// SEC_CM: MAIN.CONFIG.SPARSE
typedef enum logic [AES_OP_WIDTH-1:0] {
  AES_ENC = 2'b01,
  AES_DEC = 2'b10
} aes_op_e;

// SEC_CM: MAIN.CONFIG.SPARSE
typedef enum logic [AES_MODE_WIDTH-1:0] {
  AES_ECB  = 6'b00_0001,
  AES_CBC  = 6'b00_0010,
  AES_CFB  = 6'b00_0100,
  AES_OFB  = 6'b00_1000,
  AES_CTR  = 6'b01_0000,
  AES_NONE = 6'b10_0000
} aes_mode_e;

typedef enum logic [AES_OP_WIDTH-1:0] {
  CIPH_FWD = 2'b01,
  CIPH_INV = 2'b10
} ciph_op_e;

// SEC_CM: MAIN.CONFIG.SPARSE
typedef enum logic [AES_KEYLEN_WIDTH-1:0] {
  AES_128 = 3'b001,
  AES_192 = 3'b010,
  AES_256 = 3'b100
} key_len_e;

// SEC_CM: MAIN.CONFIG.SPARSE
typedef enum logic [AES_PRNGRESEEDRATE_WIDTH-1:0] {
  PER_1  = 3'b001,
  PER_64 = 3'b010,
  PER_8K = 3'b100
} prs_rate_e;
parameter int unsigned BlockCtrWidth = 13;

typedef struct packed {
  logic [31:7] unused;
  logic        alert_fatal_fault;
  logic        alert_recov_ctrl_update_err;
  logic        input_ready;
  logic        output_valid;
  logic        output_lost;
  logic        stall;
  logic        idle;
} status_t;

typedef struct packed {
  logic        recov_ctrl_update_err;
  logic        fatal_fault;
} alert_test_t;

  // Sparse state encodings

  // Encoding generated with:
  // $ ./util/design/sparse-fsm-encode.py -d 3 -m 8 -n 6 \
  //      -s 31468618 --language=sv
  //
  // Hamming distance histogram:
  //
  //  0: --
  //  1: --
  //  2: --
  //  3: |||||||||||||||||||| (57.14%)
  //  4: ||||||||||||||| (42.86%)
  //  5: --
  //  6: --
  //
  // Minimum Hamming distance: 3
  // Maximum Hamming distance: 4
  // Minimum Hamming weight: 1
  // Maximum Hamming weight: 5
  //
  localparam int CipherCtrlStateWidth = 6;
  typedef enum logic [CipherCtrlStateWidth-1:0] {
    CIPHER_CTRL_IDLE        = 6'b001001,
    CIPHER_CTRL_INIT        = 6'b100011,
    CIPHER_CTRL_ROUND       = 6'b111101,
    CIPHER_CTRL_FINISH      = 6'b010000,
    CIPHER_CTRL_PRNG_RESEED = 6'b100100,
    CIPHER_CTRL_CLEAR_S     = 6'b111010,
    CIPHER_CTRL_CLEAR_KD    = 6'b001110,
    CIPHER_CTRL_ERROR       = 6'b010111
  } aes_cipher_ctrl_e;

  // $ ./sparse-fsm-encode.py -d 3 -m 3 -n 5 \
  //      -s 31468618 --language=sv
  //
  // Hamming distance histogram:
  //
  //  0: --
  //  1: --
  //  2: --
  //  3: |||||||||||||||||||| (66.67%)
  //  4: |||||||||| (33.33%)
  //  5: --
  //
  // Minimum Hamming distance: 3
  // Maximum Hamming distance: 4
  //
  localparam int CtrStateWidth = 5;
  typedef enum logic [CtrStateWidth-1:0] {
    CTR_IDLE  = 5'b01110,
    CTR_INCR  = 5'b11000,
    CTR_ERROR = 5'b00001
  } aes_ctr_e;

  // Encoding generated with:
  // $ ./util/design/sparse-fsm-encode.py -d 3 -m 8 -n 6 \
  //      -s 31468618 --language=sv
  //
  // Hamming distance histogram:
  //
  //  0: --
  //  1: --
  //  2: --
  //  3: |||||||||||||||||||| (57.14%)
  //  4: ||||||||||||||| (42.86%)
  //  5: --
  //  6: --
  //
  // Minimum Hamming distance: 3
  // Maximum Hamming distance: 4
  // Minimum Hamming weight: 1
  // Maximum Hamming weight: 5
  //
  localparam int CtrlStateWidth = 6;
  typedef enum logic [CtrlStateWidth-1:0] {
    CTRL_IDLE        = 6'b001001,
    CTRL_LOAD        = 6'b100011,
    CTRL_PRNG_UPDATE = 6'b111101,
    CTRL_PRNG_RESEED = 6'b010000,
    CTRL_FINISH      = 6'b100100,
    CTRL_CLEAR_I     = 6'b111010,
    CTRL_CLEAR_CO    = 6'b001110,
    CTRL_ERROR       = 6'b010111
  } aes_ctrl_e;

// Generic, sparse mux selector encodings

// Encoding generated with:
// $ ./util/design/sparse-fsm-encode.py -d 3 -m 2 -n 3 \
//      -s 31468618 --language=sv
//
// Hamming distance histogram:
//
//  0: --
//  1: --
//  2: --
//  3: |||||||||||||||||||| (100.00%)
//
// Minimum Hamming distance: 3
// Maximum Hamming distance: 3
// Minimum Hamming weight: 1
// Maximum Hamming weight: 2
//
parameter int Mux2SelWidth = 3;
typedef enum logic [Mux2SelWidth-1:0] {
  MUX2_SEL_0 = 3'b011,
  MUX2_SEL_1 = 3'b100
} mux2_sel_e;

// Encoding generated with:
// $ ./sparse-fsm-encode.py -d 3 -m 3 -n 5 \
//      -s 31468618 --language=sv
//
// Hamming distance histogram:
//
//  0: --
//  1: --
//  2: --
//  3: |||||||||||||||||||| (66.67%)
//  4: |||||||||| (33.33%)
//  5: --
//
// Minimum Hamming distance: 3
// Maximum Hamming distance: 4
//
parameter int Mux3SelWidth = 5;
typedef enum logic [Mux3SelWidth-1:0] {
  MUX3_SEL_0 = 5'b01110,
  MUX3_SEL_1 = 5'b11000,
  MUX3_SEL_2 = 5'b00001
} mux3_sel_e;

// Encoding generated with:
// $ ./sparse-fsm-encode.py -d 3 -m 4 -n 5 \
//      -s 31468618 --language=sv
//
// Hamming distance histogram:
//
//  0: --
//  1: --
//  2: --
//  3: |||||||||||||||||||| (66.67%)
//  4: |||||||||| (33.33%)
//  5: --
//
// Minimum Hamming distance: 3
// Maximum Hamming distance: 4
//
parameter int Mux4SelWidth = 5;
typedef enum logic [Mux4SelWidth-1:0] {
  MUX4_SEL_0 = 5'b01110,
  MUX4_SEL_1 = 5'b11000,
  MUX4_SEL_2 = 5'b00001,
  MUX4_SEL_3 = 5'b10111
} mux4_sel_e;

// $ ./sparse-fsm-encode.py -d 3 -m 6 -n 6 \
//      -s 31468618 --language=sv
//
// Hamming distance histogram:
//
//  0: --
//  1: --
//  2: --
//  3: |||||||||||||||||||| (53.33%)
//  4: ||||||||||||||| (40.00%)
//  5: || (6.67%)
//  6: --
//
// Minimum Hamming distance: 3
// Maximum Hamming distance: 5
//
parameter int Mux6SelWidth = 6;
typedef enum logic [Mux6SelWidth-1:0] {
  MUX6_SEL_0 = 6'b011101,
  MUX6_SEL_1 = 6'b110000,
  MUX6_SEL_2 = 6'b001000,
  MUX6_SEL_3 = 6'b000011,
  MUX6_SEL_4 = 6'b111110,
  MUX6_SEL_5 = 6'b100101
} mux6_sel_e;

// Mux selector signal types. These use the generic types defined above.

parameter int DIPSelNum = 2;
parameter int DIPSelWidth = Mux2SelWidth;
typedef enum logic [DIPSelWidth-1:0] {
  DIP_DATA_IN = MUX2_SEL_0,
  DIP_CLEAR   = MUX2_SEL_1
} dip_sel_e;

parameter int SISelNum = 2;
parameter int SISelWidth = Mux2SelWidth;
typedef enum logic [SISelWidth-1:0] {
  SI_ZERO = MUX2_SEL_0,
  SI_DATA = MUX2_SEL_1
} si_sel_e;

parameter int AddSISelNum = 2;
parameter int AddSISelWidth = Mux2SelWidth;
typedef enum logic [AddSISelWidth-1:0] {
  ADD_SI_ZERO = MUX2_SEL_0,
  ADD_SI_IV   = MUX2_SEL_1
} add_si_sel_e;

parameter int StateSelNum = 3;
parameter int StateSelWidth = Mux3SelWidth;
typedef enum logic [StateSelWidth-1:0] {
  STATE_INIT  = MUX3_SEL_0,
  STATE_ROUND = MUX3_SEL_1,
  STATE_CLEAR = MUX3_SEL_2
} state_sel_e;

parameter int AddRKSelNum = 3;
parameter int AddRKSelWidth = Mux3SelWidth;
typedef enum logic [AddRKSelWidth-1:0] {
  ADD_RK_INIT  = MUX3_SEL_0,
  ADD_RK_ROUND = MUX3_SEL_1,
  ADD_RK_FINAL = MUX3_SEL_2
} add_rk_sel_e;

parameter int KeyInitSelNum = 3;
parameter int KeyInitSelWidth = Mux3SelWidth;
typedef enum logic [KeyInitSelWidth-1:0] {
  KEY_INIT_INPUT  = MUX3_SEL_0,
  KEY_INIT_KEYMGR = MUX3_SEL_1,
  KEY_INIT_CLEAR  = MUX3_SEL_2
} key_init_sel_e;

parameter int IVSelNum = 6;
parameter int IVSelWidth = Mux6SelWidth;
typedef enum logic [IVSelWidth-1:0] {
  IV_INPUT        = MUX6_SEL_0,
  IV_DATA_OUT     = MUX6_SEL_1,
  IV_DATA_OUT_RAW = MUX6_SEL_2,
  IV_DATA_IN_PREV = MUX6_SEL_3,
  IV_CTR          = MUX6_SEL_4,
  IV_CLEAR        = MUX6_SEL_5
} iv_sel_e;

parameter int KeyFullSelNum = 4;
parameter int KeyFullSelWidth = Mux4SelWidth;
typedef enum logic [KeyFullSelWidth-1:0] {
  KEY_FULL_ENC_INIT = MUX4_SEL_0,
  KEY_FULL_DEC_INIT = MUX4_SEL_1,
  KEY_FULL_ROUND    = MUX4_SEL_2,
  KEY_FULL_CLEAR    = MUX4_SEL_3
} key_full_sel_e;

parameter int KeyDecSelNum = 2;
parameter int KeyDecSelWidth = Mux2SelWidth;
typedef enum logic [KeyDecSelWidth-1:0] {
  KEY_DEC_EXPAND = MUX2_SEL_0,
  KEY_DEC_CLEAR  = MUX2_SEL_1
} key_dec_sel_e;

parameter int KeyWordsSelNum = 4;
parameter int KeyWordsSelWidth = Mux4SelWidth;
typedef enum logic [KeyWordsSelWidth-1:0] {
  KEY_WORDS_0123 = MUX4_SEL_0,
  KEY_WORDS_2345 = MUX4_SEL_1,
  KEY_WORDS_4567 = MUX4_SEL_2,
  KEY_WORDS_ZERO = MUX4_SEL_3
} key_words_sel_e;

parameter int RoundKeySelNum = 2;
parameter int RoundKeySelWidth = Mux2SelWidth;
typedef enum logic [RoundKeySelWidth-1:0] {
  ROUND_KEY_DIRECT = MUX2_SEL_0,
  ROUND_KEY_MIXED  = MUX2_SEL_1
} round_key_sel_e;

parameter int AddSOSelNum = 3;
parameter int AddSOSelWidth = Mux3SelWidth;
typedef enum logic [AddSOSelWidth-1:0] {
  ADD_SO_ZERO = MUX3_SEL_0,
  ADD_SO_IV   = MUX3_SEL_1,
  ADD_SO_DIP  = MUX3_SEL_2
} add_so_sel_e;

// Sparse two-value signal type sp2v_e
parameter int Sp2VNum = 2;
parameter int Sp2VWidth = Mux2SelWidth;
typedef enum logic [Sp2VWidth-1:0] {
  SP2V_HIGH = MUX2_SEL_0,
  SP2V_LOW  = MUX2_SEL_1
} sp2v_e;

typedef logic [Sp2VWidth-1:0] sp2v_logic_t;
parameter sp2v_logic_t SP2V_LOGIC_HIGH = {SP2V_HIGH};

// Control register type
typedef struct packed {
  logic      manual_operation;
  prs_rate_e prng_reseed_rate;
  logic      sideload;
  key_len_e  key_len;
  aes_mode_e mode;
  aes_op_e   operation;
} ctrl_reg_t;

parameter ctrl_reg_t CTRL_RESET = '{
  manual_operation: aes_reg_pkg::AES_CTRL_SHADOWED_MANUAL_OPERATION_RESVAL,
  prng_reseed_rate: prs_rate_e'(aes_reg_pkg::AES_CTRL_SHADOWED_PRNG_RESEED_RATE_RESVAL),
  sideload:         aes_reg_pkg::AES_CTRL_SHADOWED_SIDELOAD_RESVAL,
  key_len:          key_len_e'(aes_reg_pkg::AES_CTRL_SHADOWED_KEY_LEN_RESVAL),
  mode:             aes_mode_e'(aes_reg_pkg::AES_CTRL_SHADOWED_MODE_RESVAL),
  operation:        aes_op_e'(aes_reg_pkg::AES_CTRL_SHADOWED_OPERATION_RESVAL)
};

// Multiplication by {02} (i.e. x) on GF(2^8)
// with field generating polynomial {01}{1b} (9'h11b)
// Sometimes also denoted by xtime().
function automatic logic [7:0] aes_mul2(logic [7:0] in);
  logic [7:0] out;
  out[7] = in[6];
  out[6] = in[5];
  out[5] = in[4];
  out[4] = in[3] ^ in[7];
  out[3] = in[2] ^ in[7];
  out[2] = in[1];
  out[1] = in[0] ^ in[7];
  out[0] = in[7];
  return out;
endfunction

// Multiplication by {04} (i.e. x^2) on GF(2^8)
// with field generating polynomial {01}{1b} (9'h11b)
function automatic logic [7:0] aes_mul4(logic [7:0] in);
  return aes_mul2(aes_mul2(in));
endfunction

// Division by {02} (i.e. x) on GF(2^8)
// with field generating polynomial {01}{1b} (9'h11b)
// This is the inverse of aes_mul2() or xtime().
function automatic logic [7:0] aes_div2(logic [7:0] in);
  logic [7:0] out;
  out[7] = in[0];
  out[6] = in[7];
  out[5] = in[6];
  out[4] = in[5];
  out[3] = in[4] ^ in[0];
  out[2] = in[3] ^ in[0];
  out[1] = in[2];
  out[0] = in[1] ^ in[0];
  return out;
endfunction

// Circular byte shift to the left
function automatic logic [31:0] aes_circ_byte_shift(logic [31:0] in, logic [1:0] shift);
  logic [31:0] out;
  logic [31:0] s;
  s = {30'b0,shift};
  out = {in[8*((7-s)%4) +: 8], in[8*((6-s)%4) +: 8],
         in[8*((5-s)%4) +: 8], in[8*((4-s)%4) +: 8]};
  return out;
endfunction

// Transpose state matrix
function automatic logic [3:0][3:0][7:0] aes_transpose(logic [3:0][3:0][7:0] in);
  logic [3:0][3:0][7:0] transpose;
  transpose = '0;
  for (int j = 0; j < 4; j++) begin
    for (int i = 0; i < 4; i++) begin
      transpose[i][j] = in[j][i];
    end
  end
  return transpose;
endfunction

// Extract single column from state matrix
function automatic logic [3:0][7:0] aes_col_get(logic [3:0][3:0][7:0] in, logic [1:0] idx);
  logic [3:0][7:0] out;
  for (int i = 0; i < 4; i++) begin
    out[i] = in[i][idx];
  end
  return out;
endfunction

// Matrix-vector multiplication in GF(2^8): c = A * b
function automatic logic [7:0] aes_mvm(
  logic [7:0] vec_b,
  logic [7:0] mat_a [8]
);
  logic [7:0] vec_c;
  vec_c = '0;
  for (int i = 0; i < 8; i++) begin
    for (int j = 0; j < 8; j++) begin
      vec_c[i] = vec_c[i] ^ (mat_a[j][i] & vec_b[7-j]);
    end
  end
  return vec_c;
endfunction

// Rotate integer indices
function automatic integer aes_rot_int(integer in, integer num);
  integer out;
  if (in == 0) begin
    out = num - 1;
  end else begin
    out = in - 1;
  end
  return out;
endfunction

// Function for extracting LSBs of the per-S-Box pseudo-random data (PRD) from the output of the
// masking PRNG.
//
// The masking PRNG is used for generating both the PRD for the S-Boxes/SubBytes operation as
// well as for the input data masks. When using any of the masked Canright S-Box implementations,
// it is important that the SubBytes input masks (generated by the PRNG in Round X-1) and the
// SubBytes output masks (generated by the PRNG in Round X) are independent. Inside the PRNG,
// this is achieved by using multiple, separately re-seeded LFSR chunks and by selecting the
// separate LFSR chunks in alternating fashion. Since the input data masks become the SubBytes
// input masks in the first round, we select the same 8 bit lanes for the input data masks which
// are also used to form the SubBytes output mask for the masked Canright S-Box implementations,
// i.e., the 8 LSBs of the per S-Box PRD. In particular, we have:
//
// prng_output = { prd_key_expand, ... , sb_prd[4], sb_out_mask[4], sb_prd[0], sb_out_mask[0] }
//
// Where sb_out_mask[x] contains the SubBytes output mask for byte x (when using a masked
// Canright S-Box implementation) and sb_prd[x] contains additional PRD consumed by SubBytes for
// byte x.
//
// When using a masked S-Box implementation other than Canright, we still select the 8 LSBs of
// the per-S-Box PRD to form the input data mask of the corresponding byte. We do this to
// distribute the input data masks over all LFSR chunks of the masking PRNG.

// For one row of the state matrix, extract the 8 LSBs of the per-S-Box PRD from the PRNG output.
// These bits are used as:
// - input data masks, and
// - SubBytes output mask when using a masked Canright S-Box implementation.
function automatic logic [3:0][7:0] aes_prd_get_lsbs(
  logic [(4*WidthPRDSBox)-1:0] in
);
  logic [3:0][7:0] prd_lsbs;
  for (int i = 0; i < 4; i++) begin
    prd_lsbs[i] = in[i*WidthPRDSBox +: 8];
  end
  return prd_lsbs;
endfunction

endpackage
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES Canright SBox package
//
// For details, see the following documents:
// - Canright, "A very compact Rijndael S-box", technical report
//   available at https://hdl.handle.net/10945/25608
// - Canright, "A very compact 'perfectly masked' S-box for AES (corrected)", paper
//   available at https://eprint.iacr.org/2009/011.pdf

package aes_sbox_canright_pkg;

  // Multiplication in GF(2^2), using normal basis [Omega^2, Omega]
  // (see Figure 14 in the technical report)
  function automatic logic [1:0] aes_mul_gf2p2(logic [1:0] g, logic [1:0] d);
    logic [1:0] f;
    logic       a, b, c;
    a    = g[1] & d[1];
    b    = (^g) & (^d);
    c    = g[0] & d[0];
    f[1] = a ^ b;
    f[0] = c ^ b;
    return f;
  endfunction

  // Scale by Omega^2 = N in GF(2^2), using normal basis [Omega^2, Omega]
  // (see Figure 16 in the technical report)
  function automatic logic [1:0] aes_scale_omega2_gf2p2(logic [1:0] g);
    logic [1:0] d;
    d[1] = g[0];
    d[0] = g[1] ^ g[0];
    return d;
  endfunction

  // Scale by Omega = N^2 in GF(2^2), using normal basis [Omega^2, Omega]
  // (see Figure 15 in the technical report)
  function automatic logic [1:0] aes_scale_omega_gf2p2(logic [1:0] g);
    logic [1:0] d;
    d[1] = g[1] ^ g[0];
    d[0] = g[1];
    return d;
  endfunction

  // Square in GF(2^2), using normal basis [Omega^2, Omega]
  // (see Figures 8 and 10 in the technical report)
  function automatic logic [1:0] aes_square_gf2p2(logic [1:0] g);
    logic [1:0] d;
    d[1] = g[0];
    d[0] = g[1];
    return d;
  endfunction

  // Multiplication in GF(2^4), using normal basis [alpha^8, alpha^2]
  // (see Figure 13 in the technical report)
  function automatic logic [3:0] aes_mul_gf2p4(logic [3:0] gamma, logic [3:0] delta);
    logic [3:0] theta;
    logic [1:0] a, b, c;
    a          = aes_mul_gf2p2(gamma[3:2], delta[3:2]);
    b          = aes_mul_gf2p2(gamma[3:2] ^ gamma[1:0], delta[3:2] ^ delta[1:0]);
    c          = aes_mul_gf2p2(gamma[1:0], delta[1:0]);
    theta[3:2] = a ^ aes_scale_omega2_gf2p2(b);
    theta[1:0] = c ^ aes_scale_omega2_gf2p2(b);
    return theta;
  endfunction

  // Square and scale by nu in GF(2^4)/GF(2^2), using normal basis [alpha^8, alpha^2]
  // (see Figure 19 as well as Appendix A of the technical report)
  function automatic logic [3:0] aes_square_scale_gf2p4_gf2p2(logic [3:0] gamma);
    logic [3:0] delta;
    logic [1:0] a, b;
    a          = gamma[3:2] ^ gamma[1:0];
    b          = aes_square_gf2p2(gamma[1:0]);
    delta[3:2] = aes_square_gf2p2(a);
    delta[1:0] = aes_scale_omega_gf2p2(b);
    return delta;
  endfunction

  // Basis conversion matrices to convert between polynomial basis A, normal basis X
  // and basis S incorporating the bit matrix of the SBox. More specifically,
  // multiplication by X2X performs the transformation from normal basis X into
  // polynomial basis A, followed by the affine transformation (substep 2). Likewise,
  // multiplication by S2X performs the inverse affine transformation followed by the
  // transformation from polynomial basis A to normal basis X.
  // (see Appendix A of the technical report)
  parameter logic [7:0] A2X [8] = '{8'h98, 8'hf3, 8'hf2, 8'h48, 8'h09, 8'h81, 8'ha9, 8'hff};
  parameter logic [7:0] X2A [8] = '{8'h64, 8'h78, 8'h6e, 8'h8c, 8'h68, 8'h29, 8'hde, 8'h60};
  parameter logic [7:0] X2S [8] = '{8'h58, 8'h2d, 8'h9e, 8'h0b, 8'hdc, 8'h04, 8'h03, 8'h24};
  parameter logic [7:0] S2X [8] = '{8'h8c, 8'h79, 8'h05, 8'heb, 8'h12, 8'h04, 8'h51, 8'h53};

endpackage
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core testbench
//
// This simple testbench is mainly useful to perform some basic verification of, e.g., a
// synthesized version of the AES cipher core and/or to get an understanding of how to
// interface the core, e.g., for verifying security properties.
//
// The testbench instantiates the AES cipher core only. It performs mainly three things:
// 1. The internal masking PRNG is reseeded.
// 2. A couple of random plaintexts are encrypted with different key lenghts and random keys.
// 3. The ciphertexts produced during Step 2 are again decrypted and then compared against the
//    original plaintext values.
// While doing the encryptions and decryptions in Step 2 and Step 3, the masking PRNG is reseeded
// once per every block.

module aes_cipher_core_tb #(
) (
  input  logic clk_i,
  input  logic rst_ni,

  output logic test_done_o,
  output logic test_passed_o
);

  import aes_pkg::*;

  localparam bit          SecMasking   = 1;
  localparam sbox_impl_e  SecSBoxImpl  = SecMasking ? SBoxImplDom : SBoxImplCanright;
  localparam int          NumShares    = SecMasking ?           2 :                1;
  localparam int unsigned EntropyWidth = edn_pkg::ENDPOINT_BUS_WIDTH;

  // DUT signals
  sp2v_e                       in_ready, in_valid, out_valid;
  ciph_op_e                    op;
  key_len_e                    key_len_d, key_len_q;
  sp2v_e                       crypt, dec_key_gen;
  logic                        prng_reseed;
  logic [WidthPRDClearing-1:0] prd_clearing [NumShares];
  logic        [3:0][3:0][7:0] state_mask;
  logic        [3:0][3:0][7:0] state_init [NumShares];
  logic        [3:0][3:0][7:0] state_done [NumShares];
  logic            [7:0][31:0] key_init [NumShares];
  logic                        entropy_masking_req;
  logic     [EntropyWidth-1:0] entropy_masking;
  logic                        alert;

  // Instantiate DUT
  aes_cipher_core #(
    .SecMasking  ( SecMasking  ),
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_cipher_core (
    .clk_i            ( clk_i               ),
    .rst_ni           ( rst_ni              ),

    .in_valid_i       ( in_valid            ),
    .in_ready_o       ( in_ready            ),

    .out_valid_o      ( out_valid           ),
    .out_ready_i      ( SP2V_HIGH           ), // We're always ready.

    .cfg_valid_i      ( 1'b1                ), // Used for gating assertions only.
    .op_i             ( op                  ),
    .key_len_i        ( key_len_q           ),
    .crypt_i          ( crypt               ),
    .crypt_o          (                     ), // Ignored.
    .dec_key_gen_i    ( dec_key_gen         ),
    .dec_key_gen_o    (                     ), // Ignored.
    .prng_reseed_i    ( prng_reseed         ),
    .prng_reseed_o    (                     ), // Ignored.
    .key_clear_i      ( 1'b0                ), // Ignored.
    .key_clear_o      (                     ), // Ignored.
    .data_out_clear_i ( 1'b0                ), // Ignored.
    .data_out_clear_o (                     ), // Ignored.
    .alert_fatal_i    ( 1'b0                ), // Ignored.
    .alert_o          ( alert               ), // Ignored.

    .prd_clearing_i   ( prd_clearing        ),

    .force_masks_i    ( 1'b0                ), // Ignored.
    .data_in_mask_o   ( state_mask          ),
    .entropy_req_o    ( entropy_masking_req ),
    .entropy_ack_i    ( 1'b1                ), // This TB has always entropy available.
    .entropy_i        ( entropy_masking     ),

    .state_init_i     ( state_init          ),
    .key_init_i       ( key_init            ),
    .state_o          ( state_done          )
  );

  // TB signals.
  localparam int CipherCoreTbStateWidth = 3;
  typedef enum logic [CipherCoreTbStateWidth-1:0] {
    IDLE,
    INIT_RESEED,
    ECB_ENCRYPT,
    DEC_KEY_GEN,
    ECB_DECRYPT,
    FINISH
  } aes_cipher_core_tb_e;
  aes_cipher_core_tb_e  aes_cipher_core_tb_state_d, aes_cipher_core_tb_state_q;
  logic           [7:0] block_count_d, block_count_q;
  logic                 block_count_increment, block_count_clear;
  logic                 data_in_buf_we, data_out_buf_we, check, mismatch, test_done;
  logic [3:0][3:0][7:0] data_in_rand, data_in;
  logic [3:0][3:0][7:0] data_out;
  logic [3:0][3:0][7:0] data_in_buf[256];
  logic [3:0][3:0][7:0] data_out_buf[256];

  // Count the number of encrypted/decrypted blocks. We're doing 8 blocks with each
  // key length.
  assign block_count_d = block_count_clear     ? '0                 :
                         block_count_increment ? block_count_q + 8'h1 : block_count_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_count
    if (!rst_ni) begin
      block_count_q <= '0;
    end else begin
      block_count_q <= block_count_d;
    end
  end

  // Randomness generation.
  // Update once per block.
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_prd_clearing
    if (!rst_ni) begin
      prd_clearing <= '{default: '0};
    end else if (out_valid == SP2V_HIGH) begin
      prd_clearing <= '{default: {$urandom, $urandom}};
    end
  end

  // Update whenever requested.
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_entropy_masking
    if (!rst_ni) begin
      entropy_masking <= '0;
    end else if (entropy_masking_req) begin
      entropy_masking <= $urandom;
    end
  end

  // Input generation.
  // We use a random key. Independent of the key length, drive all key bits.
  assign key_init = '{default: {8{$urandom}}};
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_key_len
    if (!rst_ni) begin
      key_len_q <= AES_128;
    end else begin
      key_len_q <= key_len_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_data_in
    if (!rst_ni) begin
      data_in_rand <= '0;
    end else if (block_count_increment) begin
      data_in_rand <= {4{$urandom}};
    end
  end

  // For encryption we use the random data input. For decryption, we use the previous outputs.
  assign data_in =
      (aes_cipher_core_tb_state_q == ECB_DECRYPT) ? data_out_buf[block_count_q] : data_in_rand;

  // Generate the initial state.
  if (!SecMasking) begin : gen_state_init_no_masking
    // Only Share 0 is used.
    assign state_init[0] = data_in;

    // Tie-off unused signals.
    logic unused_bits;
    assign unused_bits = ^state_mask;
  end else begin : gen_state_init_masking
    // Mask the input data with the mask provided by the internal masking PRNG.
    assign state_init[0] = data_in ^ state_mask;
    assign state_init[1] = state_mask;
  end

  always_comb begin : aes_cipher_core_tb_fsm
    // DUT
    in_valid    = SP2V_LOW;
    op          = CIPH_FWD;
    crypt       = SP2V_HIGH;
    dec_key_gen = SP2V_LOW;
    prng_reseed = 1'b0;

    // TB
    aes_cipher_core_tb_state_d = aes_cipher_core_tb_state_q;
    block_count_increment      = 1'b0;
    block_count_clear          = 1'b0;
    key_len_d                  = key_len_q;
    data_in_buf_we             = 1'b0;
    data_out_buf_we            = 1'b0;
    check                      = 1'b0;
    test_done                  = 1'b0;

    unique case (aes_cipher_core_tb_state_q)

      IDLE: begin
        // Just wait for the ciphre core to become ready.
        if (in_ready == SP2V_HIGH) begin
          aes_cipher_core_tb_state_d = SecMasking ? INIT_RESEED : ECB_ENCRYPT;
        end
      end

      INIT_RESEED: begin
        // Perform an initial reseed of the internal masking PRNG to put it into a random state.
        in_valid    = SP2V_HIGH;
        crypt       = SP2V_LOW;
        prng_reseed = 1'b1;
        if (out_valid == SP2V_HIGH) begin
          aes_cipher_core_tb_state_d = ECB_ENCRYPT;
        end
      end

      ECB_ENCRYPT: begin
        // Perform encryption in parallel with a reseed of the internal masking PRNG.
        in_valid    = SP2V_HIGH;
        prng_reseed = 1'b1;
        if (out_valid == SP2V_HIGH) begin
          block_count_increment = 1'b1;
          data_in_buf_we  = 1'b1;
          data_out_buf_we = 1'b1;
          // Increase the key length after every 8 blocks.
          key_len_d = (block_count_q == 8'd7)  ? AES_192 :
                      (block_count_q == 8'd15) ? AES_256 : key_len_q;
          // After 24 blocks, we're starting over with decryption.
          if (block_count_q == 8'd23) begin
            block_count_clear          = 1'b1;
            key_len_d                  = AES_128;
            aes_cipher_core_tb_state_d = DEC_KEY_GEN;
          end
        end
      end

      DEC_KEY_GEN: begin
        // Perform encryption in parallel with a reseed of the internal masking PRNG.
        in_valid    = SP2V_HIGH;
        dec_key_gen = SP2V_HIGH;
        prng_reseed = 1'b1;
        if (out_valid == SP2V_HIGH) begin
          aes_cipher_core_tb_state_d = ECB_DECRYPT;
        end
      end

      ECB_DECRYPT: begin
        // Perform decryption in parallel with a reseed of the internal masking PRNG.
        in_valid    = SP2V_HIGH;
        op          = CIPH_INV;
        prng_reseed = 1'b1;
        if (out_valid == SP2V_HIGH) begin
          block_count_increment = 1'b1;
          check                 = 1'b1;
          // After every 8 blocks, we need to regenerate the next decryption key.
          if (block_count_q == 8'd7) begin
            key_len_d                  = AES_192;
            aes_cipher_core_tb_state_d = DEC_KEY_GEN;
          end else if (block_count_q == 8'd15) begin
            key_len_d                  = AES_256;
            aes_cipher_core_tb_state_d = DEC_KEY_GEN;
          end else if (block_count_q == 8'd23) begin
            aes_cipher_core_tb_state_d = FINISH;
          end
        end
      end

      FINISH: begin
        // Just signal end of simulation.
        test_done = 1'b1;
      end

      default: begin
        aes_cipher_core_tb_state_d = FINISH;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_fsm
    if (!rst_ni) begin
      aes_cipher_core_tb_state_q <= IDLE;
    end else begin
      aes_cipher_core_tb_state_q <= aes_cipher_core_tb_state_d;
    end
  end

  // Unmask the output.
  if (!SecMasking) begin : gen_data_out_no_masking
    assign data_out = (out_valid == SP2V_HIGH) ? state_done[0] : '0;
  end else begin : gen_data_out_masking
    assign data_out = (out_valid == SP2V_HIGH) ? state_done[1] ^ state_done[0] : '0;
  end

  // Buffering of encryption inputs and outputs for later decryption and comparison.
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_data_in_buf
    if (!rst_ni) begin
      data_in_buf <= '{default: '0};
    end else if (data_in_buf_we) begin
      data_in_buf[block_count_q] <= data_in;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_data_out_buf
    if (!rst_ni) begin
      data_out_buf <= '{default: '0};
    end else if (data_out_buf_we) begin
      data_out_buf[block_count_q] <= data_out;
    end
  end

  // Check decryption results and signal potential mismatches.
  assign mismatch = check ? (data_out != data_in_buf[block_count_q]) : 1'b0;

  // Check responses, signal end of simulation
  always_ff @(posedge clk_i or negedge rst_ni) begin : tb_ctrl
    test_done_o   <= 1'b0;
    test_passed_o <= 1'b0;

    if (rst_ni && (aes_cipher_core_tb_state_q != IDLE)) begin
      if (alert) begin
        $display("\nERROR: Fatal alert condition detected.");
        test_done_o   <= 1'b1;
      end else if (mismatch) begin
        $display("\nERROR: AES output does not match expected value.");
        test_done_o   <= 1'b1;
      end else if (test_done) begin
        $display("\nSUCCESS: All AES ciphertexts correctly decrypted.");
        test_passed_o <= 1'b1;
        test_done_o   <= 1'b1;
      end
    end

    if (block_count_q == 8'hFF) begin
      $display("\nERROR: Simulation timed out.");
      test_done_o <= 1'b1;
    end
  end

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core control FSM
//
// This module contains the AES cipher core control FSM operating on and producing the negated
// values of important control signals. This is achieved by:
// - instantiating the regular AES cipher core control FSM operating on and producing the positive
//   values of these signals, and
// - inverting these signals between the regular FSM and the caliptra_prim_buf synthesis barriers.
// Synthesis tools will then push the inverters into the actual FSM.

module aes_cipher_control_fsm_n 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit         SecMasking  = 0,
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  // Input handshake signals
  input  logic             in_valid_ni,           // Sparsify using multi-rail.
  output logic             in_ready_no,           // Sparsify using multi-rail.

  // Output handshake signals
  output logic             out_valid_no,          // Sparsify using multi-rail.
  input  logic             out_ready_ni,          // Sparsify using multi-rail.

  // Control and sync signals
  input  logic             cfg_valid_i,           // Used for SVAs only.
  input  ciph_op_e         op_i,
  input  key_len_e         key_len_i,
  input  logic             crypt_ni,              // Sparsify using multi-rail.
  input  logic             dec_key_gen_ni,        // Sparsify using multi-rail.
  input  logic             prng_reseed_i,
  input  logic             key_clear_i,
  input  logic             data_out_clear_i,
  input  logic             mux_sel_err_i,
  input  logic             sp_enc_err_i,
  input  logic             rnd_ctr_err_i,
  input  logic             op_err_i,
  input  logic             alert_fatal_i,
  output logic             alert_o,

  // Control signals for masking PRNG
  output logic             prng_update_o,
  output logic             prng_reseed_req_o,
  input  logic             prng_reseed_ack_i,

  // Control and sync signals for cipher data path
  output state_sel_e       state_sel_o,
  output logic             state_we_no,           // Sparsify using multi-rail.
  output logic             sub_bytes_en_no,       // Sparsify using multi-rail.
  input  logic             sub_bytes_out_req_ni,  // Sparsify using multi-rail.
  output logic             sub_bytes_out_ack_no,  // Sparsify using multi-rail.
  output add_rk_sel_e      add_rk_sel_o,

  // Control and sync signals for key expand data path
  output key_full_sel_e    key_full_sel_o,
  output logic             key_full_we_no,        // Sparsify using multi-rail.
  output key_dec_sel_e     key_dec_sel_o,
  output logic             key_dec_we_no,         // Sparsify using multi-rail.
  output logic             key_expand_en_no,      // Sparsify using multi-rail.
  input  logic             key_expand_out_req_ni, // Sparsify using multi-rail.
  output logic             key_expand_out_ack_no, // Sparsify using multi-rail.
  output logic             key_expand_clear_o,
  output logic [3:0]       rnd_ctr_o,
  output key_words_sel_e   key_words_sel_o,
  output round_key_sel_e   round_key_sel_o,

  // Register signals
  input  logic             crypt_q_ni,            // Sparsify using multi-rail.
  output logic             crypt_d_no,            // Sparsify using multi-rail.
  input  logic             dec_key_gen_q_ni,      // Sparsify using multi-rail.
  output logic             dec_key_gen_d_no,      // Sparsify using multi-rail.
  input  logic             prng_reseed_q_i,
  output logic             prng_reseed_d_o,
  input  logic             key_clear_q_i,
  output logic             key_clear_d_o,
  input  logic             data_out_clear_q_i,
  output logic             data_out_clear_d_o
);

  /////////////////////
  // Input Buffering //
  /////////////////////

  localparam int NumInBufBits = $bits({
    in_valid_ni,
    out_ready_ni,
    cfg_valid_i,
    op_i,
    key_len_i,
    crypt_ni,
    dec_key_gen_ni,
    prng_reseed_i,
    key_clear_i,
    data_out_clear_i,
    mux_sel_err_i,
    sp_enc_err_i,
    rnd_ctr_err_i,
    op_err_i,
    alert_fatal_i,
    prng_reseed_ack_i,
    sub_bytes_out_req_ni,
    key_expand_out_req_ni,
    crypt_q_ni,
    dec_key_gen_q_ni,
    prng_reseed_q_i,
    key_clear_q_i,
    data_out_clear_q_i
  });

  logic [NumInBufBits-1:0] in, in_buf;

  assign in = {
    in_valid_ni,
    out_ready_ni,
    cfg_valid_i,
    op_i,
    key_len_i,
    crypt_ni,
    dec_key_gen_ni,
    prng_reseed_i,
    key_clear_i,
    data_out_clear_i,
    mux_sel_err_i,
    sp_enc_err_i,
    rnd_ctr_err_i,
    op_err_i,
    alert_fatal_i,
    prng_reseed_ack_i,
    sub_bytes_out_req_ni,
    key_expand_out_req_ni,
    crypt_q_ni,
    dec_key_gen_q_ni,
    prng_reseed_q_i,
    key_clear_q_i,
    data_out_clear_q_i
  };

  // This primitive is used to place a size-only constraint on the
  // buffers to act as a synthesis optimization barrier.
  caliptra_prim_buf #(
    .Width(NumInBufBits)
  ) u_caliptra_prim_buf_in (
    .in_i(in),
    .out_o(in_buf)
  );

  logic                 in_valid_n;
  logic                 out_ready_n;
  logic                 cfg_valid;
  ciph_op_e             op;
  logic [$bits(op)-1:0] op_raw;
  key_len_e             key_len;
  logic                 crypt_n;
  logic                 dec_key_gen_n;
  logic                 prng_reseed;
  logic                 key_clear;
  logic                 data_out_clear;
  logic                 mux_sel_err;
  logic                 sp_enc_err;
  logic                 rnd_ctr_err;
  logic                 op_err;
  logic                 alert_fatal;
  logic                 prng_reseed_ack;
  logic                 sub_bytes_out_req_n;
  logic                 key_expand_out_req_n;
  logic                 crypt_q_n;
  logic                 dec_key_gen_q_n;
  logic                 prng_reseed_q;
  logic                 key_clear_q;
  logic                 data_out_clear_q;

  assign {in_valid_n,
          out_ready_n,
          cfg_valid,
          op_raw,
          key_len,
          crypt_n,
          dec_key_gen_n,
          prng_reseed,
          key_clear,
          data_out_clear,
          mux_sel_err,
          sp_enc_err,
          rnd_ctr_err,
          op_err,
          alert_fatal,
          prng_reseed_ack,
          sub_bytes_out_req_n,
          key_expand_out_req_n,
          crypt_q_n,
          dec_key_gen_q_n,
          prng_reseed_q,
          key_clear_q,
          data_out_clear_q} = in_buf;

  assign op = ciph_op_e'(op_raw);

  // Intermediate output signals
  logic             in_ready;
  logic             out_valid;
  logic             alert;
  logic             prng_update;
  logic             prng_reseed_req;
  state_sel_e       state_sel;
  logic             state_we;
  logic             sub_bytes_en;
  logic             sub_bytes_out_ack;
  add_rk_sel_e      add_rk_sel;
  key_full_sel_e    key_full_sel;
  logic             key_full_we;
  key_dec_sel_e     key_dec_sel;
  logic             key_dec_we;
  logic             key_expand_en;
  logic             key_expand_out_ack;
  logic             key_expand_clear;
  key_words_sel_e   key_words_sel;
  round_key_sel_e   round_key_sel;
  logic [3:0]       rnd_ctr;
  logic             crypt_d;
  logic             dec_key_gen_d;
  logic             prng_reseed_d;
  logic             key_clear_d;
  logic             data_out_clear_d;

  /////////////////
  // Regular FSM //
  /////////////////

  // The regular FSM operates on and produces the positive values of important control signals.
  // Invert *_n input signals here to get the positive values for the regular FSM. To obtain the
  // negated outputs, important output signals are inverted further below. Thanks to the caliptra_prim_buf
  // synthesis optimization barriers, tools will push the inverters into the regular FSM.
  aes_cipher_control_fsm #(
    .SecMasking  ( SecMasking  ),
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_cipher_control_fsm (
    .clk_i                 ( clk_i                 ),
    .rst_ni                ( rst_ni                ),

    .in_valid_i            ( ~in_valid_n           ), // Invert for regular FSM.
    .in_ready_o            ( in_ready              ), // Invert below for negated output.

    .out_valid_o           ( out_valid             ), // Invert below for negated output.
    .out_ready_i           ( ~out_ready_n          ), // Invert for regular FSM.

    .cfg_valid_i           ( cfg_valid             ),
    .op_i                  ( op                    ),
    .key_len_i             ( key_len               ),
    .crypt_i               ( ~crypt_n              ), // Invert for regular FSM.
    .dec_key_gen_i         ( ~dec_key_gen_n        ), // Invert for regular FSM.
    .prng_reseed_i         ( prng_reseed           ),
    .key_clear_i           ( key_clear             ),
    .data_out_clear_i      ( data_out_clear        ),
    .mux_sel_err_i         ( mux_sel_err           ),
    .sp_enc_err_i          ( sp_enc_err            ),
    .rnd_ctr_err_i         ( rnd_ctr_err           ),
    .op_err_i              ( op_err                ),
    .alert_fatal_i         ( alert_fatal           ),
    .alert_o               ( alert                 ),

    .prng_update_o         ( prng_update           ),
    .prng_reseed_req_o     ( prng_reseed_req       ),
    .prng_reseed_ack_i     ( prng_reseed_ack       ),

    .state_sel_o           ( state_sel             ),
    .state_we_o            ( state_we              ), // Invert below for negated output.
    .sub_bytes_en_o        ( sub_bytes_en          ), // Invert below for negated output.
    .sub_bytes_out_req_i   ( ~sub_bytes_out_req_n  ), // Invert for regular FSM.
    .sub_bytes_out_ack_o   ( sub_bytes_out_ack     ), // Invert below for negated output.
    .add_rk_sel_o          ( add_rk_sel            ),

    .key_full_sel_o        ( key_full_sel          ),
    .key_full_we_o         ( key_full_we           ), // Invert below for negated output.
    .key_dec_sel_o         ( key_dec_sel           ),
    .key_dec_we_o          ( key_dec_we            ), // Invert below for negated output.
    .key_expand_en_o       ( key_expand_en         ), // Invert below for negated output.
    .key_expand_out_req_i  ( ~key_expand_out_req_n ), // Invert for regular FSM.
    .key_expand_out_ack_o  ( key_expand_out_ack    ), // Invert below for negated output.
    .key_expand_clear_o    ( key_expand_clear      ),
    .rnd_ctr_o             ( rnd_ctr               ),
    .key_words_sel_o       ( key_words_sel         ),
    .round_key_sel_o       ( round_key_sel         ),

    .crypt_q_i             ( ~crypt_q_n            ), // Invert for regular FSM.
    .crypt_d_o             ( crypt_d               ), // Invert below for negated output.
    .dec_key_gen_q_i       ( ~dec_key_gen_q_n      ), // Invert for regular FSM.
    .dec_key_gen_d_o       ( dec_key_gen_d         ), // Invert below for negated output.
    .key_clear_q_i         ( key_clear_q           ),
    .key_clear_d_o         ( key_clear_d           ),
    .prng_reseed_q_i       ( prng_reseed_q         ),
    .prng_reseed_d_o       ( prng_reseed_d         ),
    .data_out_clear_q_i    ( data_out_clear_q      ),
    .data_out_clear_d_o    ( data_out_clear_d      )
  );

  //////////////////////
  // Output Buffering //
  //////////////////////

  localparam int NumOutBufBits = $bits({
    in_ready_no,
    out_valid_no,
    alert_o,
    prng_update_o,
    prng_reseed_req_o,
    state_sel_o,
    state_we_no,
    sub_bytes_en_no,
    sub_bytes_out_ack_no,
    add_rk_sel_o,
    key_full_sel_o,
    key_full_we_no,
    key_dec_sel_o,
    key_dec_we_no,
    key_expand_en_no,
    key_expand_out_ack_no,
    key_expand_clear_o,
    rnd_ctr_o,
    key_words_sel_o,
    round_key_sel_o,
    crypt_d_no,
    dec_key_gen_d_no,
    key_clear_d_o,
    prng_reseed_d_o,
    data_out_clear_d_o
  });

  logic [NumOutBufBits-1:0] out, out_buf;

  // Important output control signals need to be inverted here. Synthesis tools will push the
  // inverters back into the regular FSM.
  assign out = {
    ~in_ready,
    ~out_valid,
    alert,
    prng_update,
    prng_reseed_req,
    state_sel,
    ~state_we,
    ~sub_bytes_en,
    ~sub_bytes_out_ack,
    add_rk_sel,
    key_full_sel,
    ~key_full_we,
    key_dec_sel,
    ~key_dec_we,
    ~key_expand_en,
    ~key_expand_out_ack,
    key_expand_clear,
    rnd_ctr,
    key_words_sel,
    round_key_sel,
    ~crypt_d,
    ~dec_key_gen_d,
    key_clear_d,
    prng_reseed_d,
    data_out_clear_d
  };

  // This primitive is used to place a size-only constraint on the
  // buffers to act as a synthesis optimization barrier.
  caliptra_prim_buf #(
    .Width(NumOutBufBits)
  ) u_caliptra_prim_buf_out (
    .in_i(out),
    .out_o(out_buf)
  );

  assign {in_ready_no,
          out_valid_no,
          alert_o,
          prng_update_o,
          prng_reseed_req_o,
          state_sel_o,
          state_we_no,
          sub_bytes_en_no,
          sub_bytes_out_ack_no,
          add_rk_sel_o,
          key_full_sel_o,
          key_full_we_no,
          key_dec_sel_o,
          key_dec_we_no,
          key_expand_en_no,
          key_expand_out_ack_no,
          key_expand_clear_o,
          rnd_ctr_o,
          key_words_sel_o,
          round_key_sel_o,
          crypt_d_no,
          dec_key_gen_d_no,
          key_clear_d_o,
          prng_reseed_d_o,
          data_out_clear_d_o} = out_buf;

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core control FSM
//
// This module contains the AES cipher core control FSM operating on
// and producing the positive values of important control signals.

module aes_cipher_control_fsm_p 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit         SecMasking  = 0,
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  // Input handshake signals
  input  logic             in_valid_i,            // Sparsify using multi-rail.
  output logic             in_ready_o,            // Sparsify using multi-rail.

  // Output handshake signals
  output logic             out_valid_o,           // Sparsify using multi-rail.
  input  logic             out_ready_i,           // Sparsify using multi-rail.

  // Control and sync signals
  input  logic             cfg_valid_i,           // Used for SVAs only.
  input  ciph_op_e         op_i,
  input  key_len_e         key_len_i,
  input  logic             crypt_i,               // Sparsify using multi-rail.
  input  logic             dec_key_gen_i,         // Sparsify using multi-rail.
  input  logic             prng_reseed_i,
  input  logic             key_clear_i,
  input  logic             data_out_clear_i,
  input  logic             mux_sel_err_i,
  input  logic             sp_enc_err_i,
  input  logic             rnd_ctr_err_i,
  input  logic             op_err_i,
  input  logic             alert_fatal_i,
  output logic             alert_o,

  // Control signals for masking PRNG
  output logic             prng_update_o,
  output logic             prng_reseed_req_o,
  input  logic             prng_reseed_ack_i,

  // Control and sync signals for cipher data path
  output state_sel_e       state_sel_o,
  output logic             state_we_o,            // Sparsify using multi-rail.
  output logic             sub_bytes_en_o,        // Sparsify using multi-rail.
  input  logic             sub_bytes_out_req_i,   // Sparsify using multi-rail.
  output logic             sub_bytes_out_ack_o,   // Sparsify using multi-rail.
  output add_rk_sel_e      add_rk_sel_o,

  // Control and sync signals for key expand data path
  output key_full_sel_e    key_full_sel_o,
  output logic             key_full_we_o,         // Sparsify using multi-rail.
  output key_dec_sel_e     key_dec_sel_o,
  output logic             key_dec_we_o,          // Sparsify using multi-rail.
  output logic             key_expand_en_o,       // Sparsify using multi-rail.
  input  logic             key_expand_out_req_i,  // Sparsify using multi-rail.
  output logic             key_expand_out_ack_o,  // Sparsify using multi-rail.
  output logic             key_expand_clear_o,
  output logic [3:0]       rnd_ctr_o,
  output key_words_sel_e   key_words_sel_o,
  output round_key_sel_e   round_key_sel_o,

  // Register signals
  input  logic             crypt_q_i,             // Sparsify using multi-rail.
  output logic             crypt_d_o,             // Sparsify using multi-rail.
  input  logic             dec_key_gen_q_i,       // Sparsify using multi-rail.
  output logic             dec_key_gen_d_o,       // Sparsify using multi-rail.
  input  logic             prng_reseed_q_i,
  output logic             prng_reseed_d_o,
  input  logic             key_clear_q_i,
  output logic             key_clear_d_o,
  input  logic             data_out_clear_q_i,
  output logic             data_out_clear_d_o
);

  /////////////////////
  // Input Buffering //
  /////////////////////

  localparam int NumInBufBits = $bits({
    in_valid_i,
    out_ready_i,
    cfg_valid_i,
    op_i,
    key_len_i,
    crypt_i,
    dec_key_gen_i,
    prng_reseed_i,
    key_clear_i,
    data_out_clear_i,
    mux_sel_err_i,
    sp_enc_err_i,
    rnd_ctr_err_i,
    op_err_i,
    alert_fatal_i,
    prng_reseed_ack_i,
    sub_bytes_out_req_i,
    key_expand_out_req_i,
    crypt_q_i,
    dec_key_gen_q_i,
    prng_reseed_q_i,
    key_clear_q_i,
    data_out_clear_q_i
  });

  logic [NumInBufBits-1:0] in, in_buf;

  assign in = {
    in_valid_i,
    out_ready_i,
    cfg_valid_i,
    op_i,
    key_len_i,
    crypt_i,
    dec_key_gen_i,
    prng_reseed_i,
    key_clear_i,
    data_out_clear_i,
    mux_sel_err_i,
    sp_enc_err_i,
    rnd_ctr_err_i,
    op_err_i,
    alert_fatal_i,
    prng_reseed_ack_i,
    sub_bytes_out_req_i,
    key_expand_out_req_i,
    crypt_q_i,
    dec_key_gen_q_i,
    prng_reseed_q_i,
    key_clear_q_i,
    data_out_clear_q_i
  };

  // This primitive is used to place a size-only constraint on the
  // buffers to act as a synthesis optimization barrier.
  caliptra_prim_buf #(
    .Width(NumInBufBits)
  ) u_caliptra_prim_buf_in (
    .in_i(in),
    .out_o(in_buf)
  );

  logic                 in_valid;
  logic                 out_ready;
  logic                 cfg_valid;
  ciph_op_e             op;
  logic [$bits(op)-1:0] op_raw;
  key_len_e             key_len;
  logic                 crypt;
  logic                 dec_key_gen;
  logic                 prng_reseed;
  logic                 key_clear;
  logic                 data_out_clear;
  logic                 mux_sel_err;
  logic                 sp_enc_err;
  logic                 rnd_ctr_err;
  logic                 op_err;
  logic                 alert_fatal;
  logic                 prng_reseed_ack;
  logic                 sub_bytes_out_req;
  logic                 key_expand_out_req;
  logic                 crypt_q;
  logic                 dec_key_gen_q;
  logic                 prng_reseed_q;
  logic                 key_clear_q;
  logic                 data_out_clear_q;

  assign {in_valid,
          out_ready,
          cfg_valid,
          op_raw,
          key_len,
          crypt,
          dec_key_gen,
          prng_reseed,
          key_clear,
          data_out_clear,
          mux_sel_err,
          sp_enc_err,
          rnd_ctr_err,
          op_err,
          alert_fatal,
          prng_reseed_ack,
          sub_bytes_out_req,
          key_expand_out_req,
          crypt_q,
          dec_key_gen_q,
          prng_reseed_q,
          key_clear_q,
          data_out_clear_q} = in_buf;

  assign op = ciph_op_e'(op_raw);

  // Intermediate output signals
  logic             in_ready;
  logic             out_valid;
  logic             alert;
  logic             prng_update;
  logic             prng_reseed_req;
  state_sel_e       state_sel;
  logic             state_we;
  logic             sub_bytes_en;
  logic             sub_bytes_out_ack;
  add_rk_sel_e      add_rk_sel;
  key_full_sel_e    key_full_sel;
  logic             key_full_we;
  key_dec_sel_e     key_dec_sel;
  logic             key_dec_we;
  logic             key_expand_en;
  logic             key_expand_out_ack;
  logic             key_expand_clear;
  logic [3:0]       rnd_ctr;
  key_words_sel_e   key_words_sel;
  round_key_sel_e   round_key_sel;
  logic             crypt_d;
  logic             dec_key_gen_d;
  logic             prng_reseed_d;
  logic             key_clear_d;
  logic             data_out_clear_d;

  /////////////////
  // Regular FSM //
  /////////////////

  aes_cipher_control_fsm #(
    .SecMasking  ( SecMasking  ),
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_cipher_control_fsm (
    .clk_i                 ( clk_i                  ),
    .rst_ni                ( rst_ni                 ),

    .in_valid_i            ( in_valid               ),
    .in_ready_o            ( in_ready               ),

    .out_valid_o           ( out_valid              ),
    .out_ready_i           ( out_ready              ),

    .cfg_valid_i           ( cfg_valid              ),
    .op_i                  ( op                     ),
    .key_len_i             ( key_len                ),
    .crypt_i               ( crypt                  ),
    .dec_key_gen_i         ( dec_key_gen            ),
    .prng_reseed_i         ( prng_reseed            ),
    .key_clear_i           ( key_clear              ),
    .data_out_clear_i      ( data_out_clear         ),
    .mux_sel_err_i         ( mux_sel_err            ),
    .sp_enc_err_i          ( sp_enc_err             ),
    .rnd_ctr_err_i         ( rnd_ctr_err            ),
    .op_err_i              ( op_err                 ),
    .alert_fatal_i         ( alert_fatal            ),
    .alert_o               ( alert                  ),

    .prng_update_o         ( prng_update            ),
    .prng_reseed_req_o     ( prng_reseed_req        ),
    .prng_reseed_ack_i     ( prng_reseed_ack        ),

    .state_sel_o           ( state_sel              ),
    .state_we_o            ( state_we               ),
    .sub_bytes_en_o        ( sub_bytes_en           ),
    .sub_bytes_out_req_i   ( sub_bytes_out_req      ),
    .sub_bytes_out_ack_o   ( sub_bytes_out_ack      ),
    .add_rk_sel_o          ( add_rk_sel             ),

    .key_full_sel_o        ( key_full_sel           ),
    .key_full_we_o         ( key_full_we            ),
    .key_dec_sel_o         ( key_dec_sel            ),
    .key_dec_we_o          ( key_dec_we             ),
    .key_expand_en_o       ( key_expand_en          ),
    .key_expand_out_req_i  ( key_expand_out_req     ),
    .key_expand_out_ack_o  ( key_expand_out_ack     ),
    .key_expand_clear_o    ( key_expand_clear       ),
    .rnd_ctr_o             ( rnd_ctr                ),
    .key_words_sel_o       ( key_words_sel          ),
    .round_key_sel_o       ( round_key_sel          ),

    .crypt_q_i             ( crypt_q                ),
    .crypt_d_o             ( crypt_d                ),
    .dec_key_gen_q_i       ( dec_key_gen_q          ),
    .dec_key_gen_d_o       ( dec_key_gen_d          ),
    .key_clear_q_i         ( key_clear_q            ),
    .key_clear_d_o         ( key_clear_d            ),
    .prng_reseed_q_i       ( prng_reseed_q          ),
    .prng_reseed_d_o       ( prng_reseed_d          ),
    .data_out_clear_q_i    ( data_out_clear_q       ),
    .data_out_clear_d_o    ( data_out_clear_d       )
  );

  //////////////////////
  // Output Buffering //
  //////////////////////

  localparam int NumOutBufBits = $bits({
    in_ready_o,
    out_valid_o,
    alert_o,
    prng_update_o,
    prng_reseed_req_o,
    state_sel_o,
    state_we_o,
    sub_bytes_en_o,
    sub_bytes_out_ack_o,
    add_rk_sel_o,
    key_full_sel_o,
    key_full_we_o,
    key_dec_sel_o,
    key_dec_we_o,
    key_expand_en_o,
    key_expand_out_ack_o,
    key_expand_clear_o,
    rnd_ctr_o,
    key_words_sel_o,
    round_key_sel_o,
    crypt_d_o,
    dec_key_gen_d_o,
    key_clear_d_o,
    prng_reseed_d_o,
    data_out_clear_d_o
  });

  logic [NumOutBufBits-1:0] out, out_buf;

  assign out = {
    in_ready,
    out_valid,
    alert,
    prng_update,
    prng_reseed_req,
    state_sel,
    state_we,
    sub_bytes_en,
    sub_bytes_out_ack,
    add_rk_sel,
    key_full_sel,
    key_full_we,
    key_dec_sel,
    key_dec_we,
    key_expand_en,
    key_expand_out_ack,
    key_expand_clear,
    rnd_ctr,
    key_words_sel,
    round_key_sel,
    crypt_d,
    dec_key_gen_d,
    key_clear_d,
    prng_reseed_d,
    data_out_clear_d
  };

  // This primitive is used to place a size-only constraint on the
  // buffers to act as a synthesis optimization barrier.
  caliptra_prim_buf #(
    .Width(NumOutBufBits)
  ) u_caliptra_prim_buf_out (
    .in_i(out),
    .out_o(out_buf)
  );

  assign {in_ready_o,
          out_valid_o,
          alert_o,
          prng_update_o,
          prng_reseed_req_o,
          state_sel_o,
          state_we_o,
          sub_bytes_en_o,
          sub_bytes_out_ack_o,
          add_rk_sel_o,
          key_full_sel_o,
          key_full_we_o,
          key_dec_sel_o,
          key_dec_we_o,
          key_expand_en_o,
          key_expand_out_ack_o,
          key_expand_clear_o,
          rnd_ctr_o,
          key_words_sel_o,
          round_key_sel_o,
          crypt_d_o,
          dec_key_gen_d_o,
          key_clear_d_o,
          prng_reseed_d_o,
          data_out_clear_d_o} = out_buf;

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core control FSM
//
// This module contains the AES cipher core control FSM.

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_cipher_control_fsm 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit         SecMasking  = 0,
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom
) (
  input  logic             clk_i,
  input  logic             rst_ni,

  // Input handshake signals
  input  logic             in_valid_i,           // Sparsify using multi-rail.
  output logic             in_ready_o,           // Sparsify using multi-rail.

  // Output handshake signals
  output logic             out_valid_o,          // Sparsify using multi-rail.
  input  logic             out_ready_i,          // Sparsify using multi-rail.

  // Control and sync signals
  input  logic             cfg_valid_i,          // Used for SVAs only.
  input  ciph_op_e         op_i,
  input  key_len_e         key_len_i,
  input  logic             crypt_i,              // Sparsify using multi-rail.
  input  logic             dec_key_gen_i,        // Sparsify using multi-rail.
  input  logic             prng_reseed_i,
  input  logic             key_clear_i,
  input  logic             data_out_clear_i,
  input  logic             mux_sel_err_i,
  input  logic             sp_enc_err_i,
  input  logic             rnd_ctr_err_i,
  input  logic             op_err_i,
  input  logic             alert_fatal_i,
  output logic             alert_o,

  // Control signals for masking PRNG
  output logic             prng_update_o,
  output logic             prng_reseed_req_o,
  input  logic             prng_reseed_ack_i,

  // Control and sync signals for cipher data path
  output state_sel_e       state_sel_o,
  output logic             state_we_o,           // Sparsify using multi-rail.
  output logic             sub_bytes_en_o,       // Sparsify using multi-rail.
  input  logic             sub_bytes_out_req_i,  // Sparsify using multi-rail.
  output logic             sub_bytes_out_ack_o,  // Sparsify using multi-rail.
  output add_rk_sel_e      add_rk_sel_o,

  // Control and sync signals for key expand data path
  output key_full_sel_e    key_full_sel_o,
  output logic             key_full_we_o,        // Sparsify using multi-rail.
  output key_dec_sel_e     key_dec_sel_o,
  output logic             key_dec_we_o,         // Sparsify using multi-rail.
  output logic             key_expand_en_o,      // Sparsify using multi-rail.
  input  logic             key_expand_out_req_i, // Sparsify using multi-rail.
  output logic             key_expand_out_ack_o, // Sparsify using multi-rail.
  output logic             key_expand_clear_o,
  output logic [3:0]       rnd_ctr_o,
  output key_words_sel_e   key_words_sel_o,
  output round_key_sel_e   round_key_sel_o,

  // Register signals
  input  logic             crypt_q_i,            // Sparsify using multi-rail.
  output logic             crypt_d_o,            // Sparsify using multi-rail.
  input  logic             dec_key_gen_q_i,      // Sparsify using multi-rail.
  output logic             dec_key_gen_d_o,      // Sparsify using multi-rail.
  input  logic             prng_reseed_q_i,
  output logic             prng_reseed_d_o,
  input  logic             key_clear_q_i,
  output logic             key_clear_d_o,
  input  logic             data_out_clear_q_i,
  output logic             data_out_clear_d_o
);

  // cfg_valid_i is used for SVAs only.
  logic unused_cfg_valid;
  assign unused_cfg_valid = cfg_valid_i;

  // Tie off unused inputs.
  if (!SecMasking) begin : gen_unused_prng_reseed
    logic unused_prng_reseed;
    assign unused_prng_reseed = prng_reseed_i;
  end

  // Signals
  aes_cipher_ctrl_e aes_cipher_ctrl_ns, aes_cipher_ctrl_cs;
  logic             advance;
  logic       [2:0] cyc_ctr_d, cyc_ctr_q;
  logic             cyc_ctr_expr;
  logic             prng_reseed_done_d, prng_reseed_done_q;
  logic       [3:0] rnd_ctr_d, rnd_ctr_q;
  logic       [3:0] num_rounds_d, num_rounds_q;
  logic       [3:0] num_rounds_regular;

  // Use separate signal for number of regular rounds.
  assign num_rounds_regular = num_rounds_q - 4'd1;

  // FSM
  always_comb begin : aes_cipher_ctrl_fsm

    // Handshake signals
    in_ready_o           = 1'b0;
    out_valid_o          = 1'b0;

    // Masking PRNG signals
    prng_update_o        = 1'b0;
    prng_reseed_req_o    = 1'b0;

    // Cipher data path
    state_sel_o          = STATE_ROUND;
    state_we_o           = 1'b0;
    add_rk_sel_o         = ADD_RK_ROUND;
    sub_bytes_en_o       = 1'b0;
    sub_bytes_out_ack_o  = 1'b0;

    // Key expand data path
    key_full_sel_o       = KEY_FULL_ROUND;
    key_full_we_o        = 1'b0;
    key_dec_sel_o        = KEY_DEC_EXPAND;
    key_dec_we_o         = 1'b0;
    key_expand_en_o      = 1'b0;
    key_expand_out_ack_o = 1'b0;
    key_expand_clear_o   = 1'b0;
    key_words_sel_o      = KEY_WORDS_ZERO;
    round_key_sel_o      = ROUND_KEY_DIRECT;

    // FSM
    aes_cipher_ctrl_ns   = aes_cipher_ctrl_cs;
    num_rounds_d         = num_rounds_q;
    rnd_ctr_d            = rnd_ctr_q;
    crypt_d_o            = crypt_q_i;
    dec_key_gen_d_o      = dec_key_gen_q_i;
    prng_reseed_d_o      = prng_reseed_q_i;
    key_clear_d_o        = key_clear_q_i;
    data_out_clear_d_o   = data_out_clear_q_i;
    prng_reseed_done_d   = prng_reseed_done_q | prng_reseed_ack_i;
    advance              = 1'b0;
    cyc_ctr_d            = (SecSBoxImpl == SBoxImplDom) ? cyc_ctr_q + 3'd1 : 3'd0;

    // Alert
    alert_o              = 1'b0;

    unique case (aes_cipher_ctrl_cs)

      CIPHER_CTRL_IDLE: begin
        cyc_ctr_d = 3'd0;

        // Signal that we are ready, wait for handshake.
        in_ready_o = 1'b1;
        if (in_valid_i) begin
          if (SecMasking && prng_reseed_i && !dec_key_gen_i && !crypt_i) begin
            // Reseed the masking PRNG without starting encryption/decryption or generation of the
            // start key for decryption.
            prng_reseed_d_o    = 1'b1;
            prng_reseed_done_d = 1'b0;
            aes_cipher_ctrl_ns = CIPHER_CTRL_PRNG_RESEED;

          end else if (key_clear_i || data_out_clear_i) begin
            // Clear internal key registers. The cipher core muxes are used to clear the data
            // output registers.
            key_clear_d_o      = key_clear_i;
            data_out_clear_d_o = data_out_clear_i;

            // To clear the data output registers, we must first clear the state.
            aes_cipher_ctrl_ns = data_out_clear_i ? CIPHER_CTRL_CLEAR_S : CIPHER_CTRL_CLEAR_KD;

          end else if (dec_key_gen_i || crypt_i) begin
            // Start encryption/decryption or generation of start key for decryption.
            crypt_d_o       = ~dec_key_gen_i & crypt_i;
            dec_key_gen_d_o =  dec_key_gen_i;

            // Latch whether we shall reseed the masking PRNG.
            prng_reseed_d_o = SecMasking & prng_reseed_i;

            // Load input data to state
            state_sel_o = dec_key_gen_i ? STATE_CLEAR : STATE_INIT;
            state_we_o  = 1'b1;

            // Make the masking PRNG advance. The current pseudo-random data is used to mask the
            // input data.
            prng_update_o = dec_key_gen_i ? 1'b0 : SecMasking;

            // Init key expand
            key_expand_clear_o = 1'b1;

            // Load full key
            key_full_sel_o = dec_key_gen_i ? KEY_FULL_ENC_INIT :
                        (op_i == CIPH_FWD) ? KEY_FULL_ENC_INIT :
                        (op_i == CIPH_INV) ? KEY_FULL_DEC_INIT :
                                             KEY_FULL_ENC_INIT;
            key_full_we_o  = 1'b1;

            // Load num_rounds, initialize round counter.
            num_rounds_d = (key_len_i == AES_128) ? 4'd10 :
                           (key_len_i == AES_192) ? 4'd12 :
                                                    4'd14;
            rnd_ctr_d          = '0;
            aes_cipher_ctrl_ns = CIPHER_CTRL_INIT;

          end else begin
            // Handshake without a valid command. We should never get here. If we do (e.g. via a
            // malicious glitch), error out immediately.
            aes_cipher_ctrl_ns = CIPHER_CTRL_ERROR;
          end
        end
      end

      CIPHER_CTRL_INIT: begin
        // Initial round: just add key to state
        add_rk_sel_o = ADD_RK_INIT;

        // Select key words for initial add_round_key
        key_words_sel_o = (dec_key_gen_q_i)            ? KEY_WORDS_ZERO :
            (key_len_i == AES_128)                     ? KEY_WORDS_0123 :
            (key_len_i == AES_192 && op_i == CIPH_FWD) ? KEY_WORDS_0123 :
            (key_len_i == AES_192 && op_i == CIPH_INV) ? KEY_WORDS_2345 :
            (key_len_i == AES_256 && op_i == CIPH_FWD) ? KEY_WORDS_0123 :
            (key_len_i == AES_256 && op_i == CIPH_INV) ? KEY_WORDS_4567 : KEY_WORDS_ZERO;

        // Clear masking PRNG reseed status.
        prng_reseed_done_d = 1'b0;

        // AES-256 has two round keys available right from beginning. Pseudo-random data is
        // required by KeyExpand only.
        if (key_len_i != AES_256) begin
          // Advance in sync with KeyExpand. Based on the S-Box implementation, it can take
          // multiple cycles to finish. Wait for handshake. The DOM S-Boxes consume fresh PRD
          // only in the first clock cycle. By requesting the PRNG update in any clock cycle
          // other than the last one, the PRD fed into the DOM S-Boxes is guaranteed to be stable.
          // This is better in terms of SCA resistance. Request the PRNG update in the first cycle.
          advance         = key_expand_out_req_i & cyc_ctr_expr;
          prng_update_o   = (SecSBoxImpl == SBoxImplDom) ? cyc_ctr_q == 3'd0 : SecMasking;
          key_expand_en_o = 1'b1;
          if (advance) begin
            key_expand_out_ack_o = 1'b1;
            state_we_o           = ~dec_key_gen_q_i;
            key_full_we_o        = 1'b1;
            rnd_ctr_d            = rnd_ctr_q + 4'b0001;
            cyc_ctr_d            = 3'd0;
            aes_cipher_ctrl_ns   = CIPHER_CTRL_ROUND;
          end
        end else begin
          state_we_o         = ~dec_key_gen_q_i;
          rnd_ctr_d          = rnd_ctr_q + 4'b0001;
          cyc_ctr_d          = 3'd0;
          aes_cipher_ctrl_ns = CIPHER_CTRL_ROUND;
        end
      end

      CIPHER_CTRL_ROUND: begin
        // Normal rounds

        // Select key words for add_round_key
        key_words_sel_o = (dec_key_gen_q_i)            ? KEY_WORDS_ZERO :
            (key_len_i == AES_128)                     ? KEY_WORDS_0123 :
            (key_len_i == AES_192 && op_i == CIPH_FWD) ? KEY_WORDS_2345 :
            (key_len_i == AES_192 && op_i == CIPH_INV) ? KEY_WORDS_0123 :
            (key_len_i == AES_256 && op_i == CIPH_FWD) ? KEY_WORDS_4567 :
            (key_len_i == AES_256 && op_i == CIPH_INV) ? KEY_WORDS_0123 : KEY_WORDS_ZERO;

        // Keep requesting PRNG reseeding until it is acknowledged.
        prng_reseed_req_o = SecMasking & prng_reseed_q_i & ~prng_reseed_done_q;

        // Select round key: direct or mixed (equivalent inverse cipher)
        round_key_sel_o = (op_i == CIPH_FWD) ? ROUND_KEY_DIRECT :
                          (op_i == CIPH_INV) ? ROUND_KEY_MIXED  : ROUND_KEY_DIRECT;

        // Advance in sync with SubBytes and KeyExpand. Based on the S-Box implementation, both can
        // take multiple cycles to finish. Wait for handshake. The DOM S-Boxes consume fresh PRD
        // only in the first clock cycle. By requesting the PRNG update in any clock cycle other
        // than the last one, the PRD fed into the DOM S-Boxes is guaranteed to be stable. This is
        // better in terms of SCA resistance. Request the PRNG update in the first cycle. Non-DOM
        // S-Boxes need fresh PRD in every clock cycle.
        advance = key_expand_out_req_i & cyc_ctr_expr & (dec_key_gen_q_i | sub_bytes_out_req_i);
        prng_update_o   = (SecSBoxImpl == SBoxImplDom) ? cyc_ctr_q == 3'd0 : SecMasking;
        sub_bytes_en_o  = ~dec_key_gen_q_i;
        key_expand_en_o = 1'b1;

        if (advance) begin
          sub_bytes_out_ack_o  = ~dec_key_gen_q_i;
          key_expand_out_ack_o = 1'b1;

          state_we_o    = ~dec_key_gen_q_i;
          key_full_we_o = 1'b1;

          // Update round
          rnd_ctr_d     = rnd_ctr_q + 4'b0001;
          cyc_ctr_d     = 3'd0;

          // Are we doing the last regular round?
          if (rnd_ctr_q >= num_rounds_regular) begin
            aes_cipher_ctrl_ns = CIPHER_CTRL_FINISH;

            if (dec_key_gen_q_i) begin
              // Write decryption key.
              key_dec_we_o = 1'b1;

              // Indicate that we are done, try to perform the handshake. But we don't wait here.
              // If we don't get the handshake now, we will wait in the finish state. When using
              // masking, we only finish if the masking PRNG has been reseeded.
              out_valid_o = SecMasking ? (prng_reseed_q_i ? prng_reseed_done_q : 1'b1) : 1'b1;
              if (out_valid_o && out_ready_i) begin
                // Go to idle state directly.
                dec_key_gen_d_o    = 1'b0;
                prng_reseed_d_o    = 1'b0;
                aes_cipher_ctrl_ns = CIPHER_CTRL_IDLE;
              end
            end
          end // rnd_ctr_q
        end // SubBytes/KeyExpand REQ/ACK
      end

      CIPHER_CTRL_FINISH: begin
        // Final round

        // Select key words for add_round_key
        key_words_sel_o = (dec_key_gen_q_i)            ? KEY_WORDS_ZERO :
            (key_len_i == AES_128)                     ? KEY_WORDS_0123 :
            (key_len_i == AES_192 && op_i == CIPH_FWD) ? KEY_WORDS_2345 :
            (key_len_i == AES_192 && op_i == CIPH_INV) ? KEY_WORDS_0123 :
            (key_len_i == AES_256 && op_i == CIPH_FWD) ? KEY_WORDS_4567 :
            (key_len_i == AES_256 && op_i == CIPH_INV) ? KEY_WORDS_0123 : KEY_WORDS_ZERO;

        // Skip mix_columns
        add_rk_sel_o = ADD_RK_FINAL;

        // Keep requesting PRNG reseeding until it is acknowledged.
        prng_reseed_req_o = SecMasking & prng_reseed_q_i & ~prng_reseed_done_q;

        // SEC_CM: DATA_REG.KEY.SCA
        // Once we're done, we won't need the state anymore. We actually clear it when progressing
        // to the next state.
        state_sel_o = STATE_CLEAR;

        // SEC_CM: DATA_REG.LOCAL_ESC
        // Advance in sync with SubBytes. Based on the S-Box implementation, it can take multiple
        // cycles to finish. Only indicate that we are done if:
        // - we have valid output (SubBytes finished),
        // - the masking PRNG has been reseeded (if masking is used),
        // - all mux selector signals are valid (don't release data in case of errors), and
        // - all sparsely encoded signals are valid (don't release data in case of errors).
        // Perform both handshakes simultaneously.
        advance        = (sub_bytes_out_req_i & cyc_ctr_expr) | dec_key_gen_q_i;
        sub_bytes_en_o = ~dec_key_gen_q_i;
        out_valid_o    = (mux_sel_err_i || sp_enc_err_i || op_err_i) ? 1'b0         :
            SecMasking ? (prng_reseed_q_i ? prng_reseed_done_q & advance : advance) : advance;

        // Stop updating the cycle counter once we have valid output.
        cyc_ctr_d =
            (SecSBoxImpl == SBoxImplDom) ? (!advance ? cyc_ctr_q + 3'd1 : cyc_ctr_q) : 3'd0;

        // The DOM S-Boxes consume fresh PRD only in the first clock cycle. By requesting the PRNG
        // update in any clock cycle other than the last one, the PRD fed into the DOM S-Boxes is
        // guaranteed to be stable. This is better in terms of SCA resistance. Request the PRNG
        // update in the first cycle. We update it only once and in the last cycle for non-DOM
        // S-Boxes where otherwise updating the PRNG while being stalled would cause the S-Boxes
        // to be re-evaluated, thereby creating additional SCA leakage.
        prng_update_o =
            (SecSBoxImpl == SBoxImplDom) ? cyc_ctr_q == 3'd0 : out_valid_o & out_ready_i;

        if (out_valid_o && out_ready_i) begin
          sub_bytes_out_ack_o = ~dec_key_gen_q_i;

          // Clear the state.
          state_we_o          = 1'b1;
          crypt_d_o           = 1'b0;
          cyc_ctr_d           = 3'd0;
          // If we were generating the decryption key and didn't get the handshake in the last
          // regular round, we should clear dec_key_gen now.
          dec_key_gen_d_o     = 1'b0;
          prng_reseed_d_o     = 1'b0;
          aes_cipher_ctrl_ns  = CIPHER_CTRL_IDLE;
        end
      end

      CIPHER_CTRL_PRNG_RESEED: begin
        // Keep requesting PRNG reseeding until it is acknowledged.
        prng_reseed_req_o = prng_reseed_q_i & ~prng_reseed_done_q;

        // Once we're done, wait for handshake.
        out_valid_o = prng_reseed_done_q;
        if (out_valid_o && out_ready_i) begin
          prng_reseed_d_o    = 1'b0;
          aes_cipher_ctrl_ns = CIPHER_CTRL_IDLE;
        end
      end

      CIPHER_CTRL_CLEAR_S: begin
        // Clear the state with pseudo-random data.
        state_we_o         = 1'b1;
        state_sel_o        = STATE_CLEAR;
        aes_cipher_ctrl_ns = CIPHER_CTRL_CLEAR_KD;
      end

      CIPHER_CTRL_CLEAR_KD: begin
        // Clear internal key registers and/or external data output registers.
        if (key_clear_q_i) begin
          key_full_sel_o = KEY_FULL_CLEAR;
          key_full_we_o  = 1'b1;
          key_dec_sel_o  = KEY_DEC_CLEAR;
          key_dec_we_o   = 1'b1;
        end
        if (data_out_clear_q_i) begin
          // Forward the state (previously cleared with psuedo-random data).
          // SEC_CM: DATA_REG.SEC_WIPE
          add_rk_sel_o    = ADD_RK_INIT;
          key_words_sel_o = KEY_WORDS_ZERO;
          round_key_sel_o = ROUND_KEY_DIRECT;
        end
        // Indicate that we are done, wait for handshake.
        out_valid_o = 1'b1;
        if (out_ready_i) begin
          key_clear_d_o      = 1'b0;
          data_out_clear_d_o = 1'b0;
          aes_cipher_ctrl_ns = CIPHER_CTRL_IDLE;
        end
      end

      CIPHER_CTRL_ERROR: begin
        // SEC_CM: CIPHER.FSM.LOCAL_ESC
        // Terminal error state
        alert_o = 1'b1;
      end

      // We should never get here. If we do (e.g. via a malicious glitch), error out immediately.
      default: begin
        aes_cipher_ctrl_ns = CIPHER_CTRL_ERROR;
        alert_o = 1'b1;
      end
    endcase

    // Unconditionally jump into the terminal error state in case a mux selector or a sparsely
    // encoded signal becomes invalid, in case we have detected a fault in the round counter,
    // or if a fatal alert has been triggered.
    if (mux_sel_err_i || sp_enc_err_i || rnd_ctr_err_i || op_err_i || alert_fatal_i) begin
      aes_cipher_ctrl_ns = CIPHER_CTRL_ERROR;
    end
  end

  // SEC_CM: CIPHER.FSM.SPARSE
  `CALIPTRA_PRIM_FLOP_SPARSE_FSM(u_state_regs, aes_cipher_ctrl_ns,
      aes_cipher_ctrl_cs, aes_cipher_ctrl_e, CIPHER_CTRL_IDLE)

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_fsm
    if (!rst_ni) begin
      prng_reseed_done_q <= 1'b0;
      rnd_ctr_q          <= '0;
      num_rounds_q       <= '0;
    end else begin
      prng_reseed_done_q <= prng_reseed_done_d;
      rnd_ctr_q          <= rnd_ctr_d;
      num_rounds_q       <= num_rounds_d;
    end
  end

  assign rnd_ctr_o = rnd_ctr_q;

  if (SecSBoxImpl == SBoxImplDom) begin : gen_cyc_ctr
    always_ff @(posedge clk_i or negedge rst_ni) begin : reg_cyc_ctr
      if (!rst_ni) begin
        cyc_ctr_q <= 3'd0;
      end else begin
        cyc_ctr_q <= cyc_ctr_d;
      end
    end
    assign cyc_ctr_expr = cyc_ctr_q >= 3'd4;
  end else begin : gen_no_cyc_ctr
    logic [2:0] unused_cyc_ctr;
    assign cyc_ctr_q      = cyc_ctr_d;
    assign unused_cyc_ctr = cyc_ctr_q;
    assign cyc_ctr_expr   = 1'b1;
  end

  ////////////////
  // Assertions //
  ////////////////

  // Create a lint error to reduce the risk of accidentally disabling the masking.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesCipherControlFsmSecMaskingNonDefault, SecMasking == 1)

  // Create a lint error to reduce the risk of accidentally using a less secure SBox
  // implementation.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesCipherControlFsmSecSBoxImplNonDefault, SecSBoxImpl == SBoxImplDom)

  // Selectors must be known/valid
  `CALIPTRA_ASSERT(AesCiphOpValid, cfg_valid_i |-> op_i inside {
      CIPH_FWD,
      CIPH_INV
      })
  `CALIPTRA_ASSERT(AesKeyLenValid, cfg_valid_i |-> key_len_i inside {
      AES_128,
      AES_192,
      AES_256
      })
  `CALIPTRA_ASSERT(AesCipherControlStateValid, !alert_o |-> aes_cipher_ctrl_cs inside {
      CIPHER_CTRL_IDLE,
      CIPHER_CTRL_INIT,
      CIPHER_CTRL_ROUND,
      CIPHER_CTRL_FINISH,
      CIPHER_CTRL_PRNG_RESEED,
      CIPHER_CTRL_CLEAR_S,
      CIPHER_CTRL_CLEAR_KD
      })

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core control
//
// This module controls the AES cipher core including the key expand module.

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_cipher_control 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit         SecMasking  = 0,
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  // Input handshake signals
  input  sp2v_e                   in_valid_i,
  output sp2v_e                   in_ready_o,

  // Output handshake signals
  output sp2v_e                   out_valid_o,
  input  sp2v_e                   out_ready_i,

  // Control and sync signals
  input  logic                    cfg_valid_i,
  input  ciph_op_e                op_i,
  input  key_len_e                key_len_i,
  input  sp2v_e                   crypt_i,
  output sp2v_e                   crypt_o,
  input  sp2v_e                   dec_key_gen_i,
  output sp2v_e                   dec_key_gen_o,
  input  logic                    prng_reseed_i,
  output logic                    prng_reseed_o,
  input  logic                    key_clear_i,
  output logic                    key_clear_o,
  input  logic                    data_out_clear_i,
  output logic                    data_out_clear_o,
  input  logic                    mux_sel_err_i,
  input  logic                    sp_enc_err_i,
  input  logic                    op_err_i,
  input  logic                    alert_fatal_i,
  output logic                    alert_o,

  // Control signals for masking PRNG
  output logic                    prng_update_o,
  output logic                    prng_reseed_req_o,
  input  logic                    prng_reseed_ack_i,

  // Control and sync signals for cipher data path
  output state_sel_e              state_sel_o,
  output sp2v_e                   state_we_o,
  output sp2v_e                   sub_bytes_en_o,
  input  sp2v_e                   sub_bytes_out_req_i,
  output sp2v_e                   sub_bytes_out_ack_o,
  output add_rk_sel_e             add_rk_sel_o,

  // Control and sync signals for key expand data path
  output ciph_op_e                key_expand_op_o,
  output key_full_sel_e           key_full_sel_o,
  output sp2v_e                   key_full_we_o,
  output key_dec_sel_e            key_dec_sel_o,
  output sp2v_e                   key_dec_we_o,
  output sp2v_e                   key_expand_en_o,
  input  sp2v_e                   key_expand_out_req_i,
  output sp2v_e                   key_expand_out_ack_o,
  output logic                    key_expand_clear_o,
  output logic [3:0]              key_expand_round_o,
  output key_words_sel_e          key_words_sel_o,
  output round_key_sel_e          round_key_sel_o
);

  // Signals
  logic                          [3:0] rnd_ctr;
  sp2v_e                               crypt_d, crypt_q;
  sp2v_e                               dec_key_gen_d, dec_key_gen_q;
  logic                                prng_reseed_d, prng_reseed_q;
  logic                                key_clear_d, key_clear_q;
  logic                                data_out_clear_d, data_out_clear_q;
  sp2v_e                               sub_bytes_out_req;
  sp2v_e                               key_expand_out_req;
  sp2v_e                               in_valid;
  sp2v_e                               out_ready;
  sp2v_e                               crypt;
  sp2v_e                               dec_key_gen;
  logic                                mux_sel_err;
  logic                                mr_err;
  logic                                sp_enc_err;
  logic                                rnd_ctr_err;

  // Sparsified FSM signals. These are needed for connecting the individual bits of the Sp2V
  // signals to the single-rail FSMs.
  logic           [Sp2VWidth-1:0]      sp_in_valid;
  logic           [Sp2VWidth-1:0]      sp_in_ready;
  logic           [Sp2VWidth-1:0]      sp_out_valid;
  logic           [Sp2VWidth-1:0]      sp_out_ready;
  logic           [Sp2VWidth-1:0]      sp_crypt;
  logic           [Sp2VWidth-1:0]      sp_dec_key_gen;
  logic           [Sp2VWidth-1:0]      sp_state_we;
  logic           [Sp2VWidth-1:0]      sp_sub_bytes_en;
  logic           [Sp2VWidth-1:0]      sp_sub_bytes_out_req;
  logic           [Sp2VWidth-1:0]      sp_sub_bytes_out_ack;
  logic           [Sp2VWidth-1:0]      sp_key_full_we;
  logic           [Sp2VWidth-1:0]      sp_key_dec_we;
  logic           [Sp2VWidth-1:0]      sp_key_expand_en;
  logic           [Sp2VWidth-1:0]      sp_key_expand_out_req;
  logic           [Sp2VWidth-1:0]      sp_key_expand_out_ack;
  logic           [Sp2VWidth-1:0]      sp_crypt_d;
  logic           [Sp2VWidth-1:0]      sp_crypt_q;
  logic           [Sp2VWidth-1:0]      sp_dec_key_gen_d;
  logic           [Sp2VWidth-1:0]      sp_dec_key_gen_q;

  // Multi-rail signals. These are outputs of the single-rail FSMs and need combining.
  logic           [Sp2VWidth-1:0]      mr_alert;
  logic           [Sp2VWidth-1:0]      mr_prng_update;
  logic           [Sp2VWidth-1:0]      mr_prng_reseed_req;
  logic           [Sp2VWidth-1:0]      mr_key_expand_clear;
  logic           [Sp2VWidth-1:0]      mr_prng_reseed_d;
  logic           [Sp2VWidth-1:0]      mr_key_clear_d;
  logic           [Sp2VWidth-1:0]      mr_data_out_clear_d;

  state_sel_e     [Sp2VWidth-1:0]      mr_state_sel;
  add_rk_sel_e    [Sp2VWidth-1:0]      mr_add_rk_sel;
  key_full_sel_e  [Sp2VWidth-1:0]      mr_key_full_sel;
  key_dec_sel_e   [Sp2VWidth-1:0]      mr_key_dec_sel;
  key_words_sel_e [Sp2VWidth-1:0]      mr_key_words_sel;
  round_key_sel_e [Sp2VWidth-1:0]      mr_round_key_sel;

  logic           [Sp2VWidth-1:0][3:0] mr_rnd_ctr;

  /////////
  // FSM //
  /////////

  // Convert sp2v_e signals to sparsified inputs.
  assign sp_in_valid           = {in_valid};
  assign sp_out_ready          = {out_ready};
  assign sp_crypt              = {crypt};
  assign sp_dec_key_gen        = {dec_key_gen};
  assign sp_sub_bytes_out_req  = {sub_bytes_out_req};
  assign sp_key_expand_out_req = {key_expand_out_req};
  assign sp_crypt_q            = {crypt_q};
  assign sp_dec_key_gen_q      = {dec_key_gen_q};

  // SEC_CM: CIPHER.FSM.REDUN
  // SEC_CM: CIPHER.CTR.REDUN
  // For every bit in the Sp2V signals, one separate rail is instantiated. The inputs and outputs
  // of every rail are buffered to prevent aggressive synthesis optimizations.
  for (genvar i = 0; i < Sp2VWidth; i++) begin : gen_fsm
    if (SP2V_LOGIC_HIGH[i] == 1'b1) begin : gen_fsm_p
      aes_cipher_control_fsm_p #(
        .SecMasking  ( SecMasking  ),
        .SecSBoxImpl ( SecSBoxImpl )
      ) u_aes_cipher_control_fsm_i (
        .clk_i                 ( clk_i                    ),
        .rst_ni                ( rst_ni                   ),

        .in_valid_i            ( sp_in_valid[i]           ), // Sparsified
        .in_ready_o            ( sp_in_ready[i]           ), // Sparsified

        .out_valid_o           ( sp_out_valid[i]          ), // Sparsified
        .out_ready_i           ( sp_out_ready[i]          ), // Sparsified

        .cfg_valid_i           ( cfg_valid_i              ),
        .op_i                  ( op_i                     ),
        .key_len_i             ( key_len_i                ),
        .crypt_i               ( sp_crypt[i]              ), // Sparsified
        .dec_key_gen_i         ( sp_dec_key_gen[i]        ), // Sparsified
        .prng_reseed_i         ( prng_reseed_i            ),
        .key_clear_i           ( key_clear_i              ),
        .data_out_clear_i      ( data_out_clear_i         ),
        .mux_sel_err_i         ( mux_sel_err              ),
        .sp_enc_err_i          ( sp_enc_err               ),
        .rnd_ctr_err_i         ( rnd_ctr_err              ),
        .op_err_i              ( op_err_i                 ),
        .alert_fatal_i         ( alert_fatal_i            ),
        .alert_o               ( mr_alert[i]              ), // OR-combine

        .prng_update_o         ( mr_prng_update[i]        ), // OR-combine
        .prng_reseed_req_o     ( mr_prng_reseed_req[i]    ), // OR-combine
        .prng_reseed_ack_i     ( prng_reseed_ack_i        ),

        .state_sel_o           ( mr_state_sel[i]          ), // OR-combine
        .state_we_o            ( sp_state_we[i]           ), // Sparsified
        .sub_bytes_en_o        ( sp_sub_bytes_en[i]       ), // Sparsified
        .sub_bytes_out_req_i   ( sp_sub_bytes_out_req[i]  ), // Sparsified
        .sub_bytes_out_ack_o   ( sp_sub_bytes_out_ack[i]  ), // Sparsified
        .add_rk_sel_o          ( mr_add_rk_sel[i]         ), // OR-combine

        .key_full_sel_o        ( mr_key_full_sel[i]       ), // OR-combine
        .key_full_we_o         ( sp_key_full_we[i]        ), // Sparsified
        .key_dec_sel_o         ( mr_key_dec_sel[i]        ), // OR-combine
        .key_dec_we_o          ( sp_key_dec_we[i]         ), // Sparsified
        .key_expand_en_o       ( sp_key_expand_en[i]      ), // Sparsified
        .key_expand_out_req_i  ( sp_key_expand_out_req[i] ), // Sparsified
        .key_expand_out_ack_o  ( sp_key_expand_out_ack[i] ), // Sparsified
        .key_expand_clear_o    ( mr_key_expand_clear[i]   ), // OR-combine
        .rnd_ctr_o             ( mr_rnd_ctr[i]            ), // OR-combine
        .key_words_sel_o       ( mr_key_words_sel[i]      ), // OR-combine
        .round_key_sel_o       ( mr_round_key_sel[i]      ), // OR-combine

        .crypt_q_i             ( sp_crypt_q[i]            ), // Sparsified
        .crypt_d_o             ( sp_crypt_d[i]            ), // Sparsified
        .dec_key_gen_q_i       ( sp_dec_key_gen_q[i]      ), // Sparsified
        .dec_key_gen_d_o       ( sp_dec_key_gen_d[i]      ), // Sparsified
        .prng_reseed_q_i       ( prng_reseed_q            ),
        .prng_reseed_d_o       ( mr_prng_reseed_d[i]      ), // AND-combine
        .key_clear_q_i         ( key_clear_q              ),
        .key_clear_d_o         ( mr_key_clear_d[i]        ), // AND-combine
        .data_out_clear_q_i    ( data_out_clear_q         ),
        .data_out_clear_d_o    ( mr_data_out_clear_d[i]   )  // AND-combine
      );
    end else begin : gen_fsm_n
      aes_cipher_control_fsm_n #(
        .SecMasking  ( SecMasking  ),
        .SecSBoxImpl ( SecSBoxImpl )
      ) u_aes_cipher_control_fsm_i (
        .clk_i                 ( clk_i                    ),
        .rst_ni                ( rst_ni                   ),

        .in_valid_ni           ( sp_in_valid[i]           ), // Sparsified
        .in_ready_no           ( sp_in_ready[i]           ), // Sparsified

        .out_valid_no          ( sp_out_valid[i]          ), // Sparsified
        .out_ready_ni          ( sp_out_ready[i]          ), // Sparsified

        .cfg_valid_i           ( cfg_valid_i              ),
        .op_i                  ( op_i                     ),
        .key_len_i             ( key_len_i                ),
        .crypt_ni              ( sp_crypt[i]              ), // Sparsified
        .dec_key_gen_ni        ( sp_dec_key_gen[i]        ), // Sparsified
        .prng_reseed_i         ( prng_reseed_i            ),
        .key_clear_i           ( key_clear_i              ),
        .data_out_clear_i      ( data_out_clear_i         ),
        .mux_sel_err_i         ( mux_sel_err              ),
        .sp_enc_err_i          ( sp_enc_err               ),
        .rnd_ctr_err_i         ( rnd_ctr_err              ),
        .op_err_i              ( op_err_i                 ),
        .alert_fatal_i         ( alert_fatal_i            ),
        .alert_o               ( mr_alert[i]              ), // OR-combine

        .prng_update_o         ( mr_prng_update[i]        ), // OR-combine
        .prng_reseed_req_o     ( mr_prng_reseed_req[i]    ), // OR-combine
        .prng_reseed_ack_i     ( prng_reseed_ack_i        ),

        .state_sel_o           ( mr_state_sel[i]          ), // OR-combine
        .state_we_no           ( sp_state_we[i]           ), // Sparsified
        .sub_bytes_en_no       ( sp_sub_bytes_en[i]       ), // Sparsified
        .sub_bytes_out_req_ni  ( sp_sub_bytes_out_req[i]  ), // Sparsified
        .sub_bytes_out_ack_no  ( sp_sub_bytes_out_ack[i]  ), // Sparsified
        .add_rk_sel_o          ( mr_add_rk_sel[i]         ), // OR-combine

        .key_full_sel_o        ( mr_key_full_sel[i]       ), // OR-combine
        .key_full_we_no        ( sp_key_full_we[i]        ), // Sparsified
        .key_dec_sel_o         ( mr_key_dec_sel[i]        ), // OR-combine
        .key_dec_we_no         ( sp_key_dec_we[i]         ), // Sparsified
        .key_expand_en_no      ( sp_key_expand_en[i]      ), // Sparsified
        .key_expand_out_req_ni ( sp_key_expand_out_req[i] ), // Sparsified
        .key_expand_out_ack_no ( sp_key_expand_out_ack[i] ), // Sparsified
        .key_expand_clear_o    ( mr_key_expand_clear[i]   ), // OR-combine
        .rnd_ctr_o             ( mr_rnd_ctr[i]            ), // OR-combine
        .key_words_sel_o       ( mr_key_words_sel[i]      ), // OR-combine
        .round_key_sel_o       ( mr_round_key_sel[i]      ), // OR-combine

        .crypt_q_ni            ( sp_crypt_q[i]            ), // Sparsified
        .crypt_d_no            ( sp_crypt_d[i]            ), // Sparsified
        .dec_key_gen_q_ni      ( sp_dec_key_gen_q[i]      ), // Sparsified
        .dec_key_gen_d_no      ( sp_dec_key_gen_d[i]      ), // Sparsified
        .prng_reseed_q_i       ( prng_reseed_q            ),
        .prng_reseed_d_o       ( mr_prng_reseed_d[i]      ), // AND-combine
        .key_clear_q_i         ( key_clear_q              ),
        .key_clear_d_o         ( mr_key_clear_d[i]        ), // AND-combine
        .data_out_clear_q_i    ( data_out_clear_q         ),
        .data_out_clear_d_o    ( mr_data_out_clear_d[i]   )  // AND-combine
      );
    end
  end

  // Convert sparsified outputs to sp2v_e type.
  assign in_ready_o           = sp2v_e'(sp_in_ready);
  assign out_valid_o          = sp2v_e'(sp_out_valid);
  assign state_we_o           = sp2v_e'(sp_state_we);
  assign sub_bytes_en_o       = sp2v_e'(sp_sub_bytes_en);
  assign sub_bytes_out_ack_o  = sp2v_e'(sp_sub_bytes_out_ack);
  assign key_full_we_o        = sp2v_e'(sp_key_full_we);
  assign key_dec_we_o         = sp2v_e'(sp_key_dec_we);
  assign key_expand_en_o      = sp2v_e'(sp_key_expand_en);
  assign key_expand_out_ack_o = sp2v_e'(sp_key_expand_out_ack);
  assign crypt_d              = sp2v_e'(sp_crypt_d);
  assign dec_key_gen_d        = sp2v_e'(sp_dec_key_gen_d);

  // Combine single-bit FSM outputs.
  // OR: One bit is sufficient to drive the corresponding output bit high.
  assign alert_o            = |mr_alert;
  assign prng_update_o      = |mr_prng_update;
  assign prng_reseed_req_o  = |mr_prng_reseed_req;
  assign key_expand_clear_o = |mr_key_expand_clear;
  // AND: Only if all bits are high, the corresponding status is signaled which will lead to
  // the clearing of these trigger bits.
  assign prng_reseed_d      = &mr_prng_reseed_d;
  assign key_clear_d        = &mr_key_clear_d;
  assign data_out_clear_d   = &mr_data_out_clear_d;

  // Combine multi-bit, sparse FSM outputs. We simply OR them together. If the FSMs don't provide
  // the same outputs, two cases are possible:
  // - An invalid encoding results: A downstream checker will fire, see mux_sel_err_i.
  // - A valid encoding results: The outputs are compared below to cover this case, see mr_err;
  always_comb begin : combine_sparse_signals
    state_sel_o     = state_sel_e'({StateSelWidth{1'b0}});
    add_rk_sel_o    = add_rk_sel_e'({AddRKSelWidth{1'b0}});
    key_full_sel_o  = key_full_sel_e'({KeyFullSelWidth{1'b0}});
    key_dec_sel_o   = key_dec_sel_e'({KeyDecSelWidth{1'b0}});
    key_words_sel_o = key_words_sel_e'({KeyWordsSelWidth{1'b0}});
    round_key_sel_o = round_key_sel_e'({RoundKeySelWidth{1'b0}});
    mr_err          = 1'b0;

    for (int i = 0; i < Sp2VWidth; i++) begin
      state_sel_o     = state_sel_e'({state_sel_o}         | {mr_state_sel[i]});
      add_rk_sel_o    = add_rk_sel_e'({add_rk_sel_o}       | {mr_add_rk_sel[i]});
      key_full_sel_o  = key_full_sel_e'({key_full_sel_o}   | {mr_key_full_sel[i]});
      key_dec_sel_o   = key_dec_sel_e'({key_dec_sel_o}     | {mr_key_dec_sel[i]});
      key_words_sel_o = key_words_sel_e'({key_words_sel_o} | {mr_key_words_sel[i]});
      round_key_sel_o = round_key_sel_e'({round_key_sel_o} | {mr_round_key_sel[i]});
    end

    for (int i = 0; i < Sp2VWidth; i++) begin
      if (state_sel_o     != mr_state_sel[i]     ||
          add_rk_sel_o    != mr_add_rk_sel[i]    ||
          key_full_sel_o  != mr_key_full_sel[i]  ||
          key_dec_sel_o   != mr_key_dec_sel[i]   ||
          key_words_sel_o != mr_key_words_sel[i] ||
          round_key_sel_o != mr_round_key_sel[i]) begin
        mr_err = 1'b1;
      end
    end
  end

  // Collect errors in mux selector signals.
  assign mux_sel_err = mux_sel_err_i | mr_err;

  // Combine counter signals. We simply OR them together. If the FSMs don't provide the same
  // outputs, rnd_ctr_err will be set.
  always_comb begin : combine_counter_signals
    rnd_ctr     = '0;
    rnd_ctr_err = 1'b0;
    for (int i = 0; i < Sp2VWidth; i++) begin
      rnd_ctr |= mr_rnd_ctr[i];
    end

    for (int i = 0; i < Sp2VWidth; i++) begin
      if (rnd_ctr != mr_rnd_ctr[i]) begin
        rnd_ctr_err = 1'b1;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_fsm
    if (!rst_ni) begin
      prng_reseed_q      <= 1'b0;
      key_clear_q        <= 1'b0;
      data_out_clear_q   <= 1'b0;
    end else begin
      prng_reseed_q      <= prng_reseed_d;
      key_clear_q        <= key_clear_d;
      data_out_clear_q   <= data_out_clear_d;
    end
  end

  // Use separate signal for key expand operation, forward round.
  assign key_expand_op_o    = (dec_key_gen_d == SP2V_HIGH ||
                               dec_key_gen_q == SP2V_HIGH) ? CIPH_FWD : op_i;
  assign key_expand_round_o = rnd_ctr;

  // Let the main controller know whate we are doing.
  assign crypt_o          = crypt_q;
  assign dec_key_gen_o    = dec_key_gen_q;
  assign prng_reseed_o    = prng_reseed_q;
  assign key_clear_o      = key_clear_q;
  assign data_out_clear_o = data_out_clear_q;


  //////////////////////////////
  // Sparsely Encoded Signals //
  //////////////////////////////

  // SEC_CM: CTRL.SPARSE
  // We use sparse encodings for various critical signals and must ensure that:
  // 1. The synthesis tool doesn't optimize away the sparse encoding.
  // 2. The sparsely encoded signal is always valid. More precisely, an alert or SVA is triggered
  //    if a sparse signal takes on an invalid value.
  // 3. The alert signal remains asserted until reset even if the sparse signal becomes valid again
  //    This is achieved by driving the control FSM into the terminal error state whenever any
  //    sparsely encoded signal becomes invalid.
  //
  // If any sparsely encoded signal becomes invalid, the cipher core further immediately de-asserts
  // the out_valid_o signal to prevent any data from being released.

  // The following primitives are used to place a size-only constraint on the
  // flops in order to prevent optimizations on these status signals.
  logic [Sp2VWidth-1:0] crypt_q_raw;
  caliptra_prim_flop #(
    .Width      ( Sp2VWidth            ),
    .ResetValue ( Sp2VWidth'(SP2V_LOW) )
  ) u_crypt_regs (
    .clk_i  ( clk_i       ),
    .rst_ni ( rst_ni      ),
    .d_i    ( crypt_d     ),
    .q_o    ( crypt_q_raw )
  );

  logic [Sp2VWidth-1:0] dec_key_gen_q_raw;
  caliptra_prim_flop #(
    .Width      ( Sp2VWidth            ),
    .ResetValue ( Sp2VWidth'(SP2V_LOW) )
  ) u_dec_key_gen_regs (
    .clk_i  ( clk_i             ),
    .rst_ni ( rst_ni            ),
    .d_i    ( dec_key_gen_d     ),
    .q_o    ( dec_key_gen_q_raw )
  );

  // We use vectors of sparsely encoded signals to reduce code duplication.
  localparam int unsigned NumSp2VSig = 8;
  sp2v_e [NumSp2VSig-1:0]                sp2v_sig;
  sp2v_e [NumSp2VSig-1:0]                sp2v_sig_chk;
  logic  [NumSp2VSig-1:0][Sp2VWidth-1:0] sp2v_sig_chk_raw;
  logic  [NumSp2VSig-1:0]                sp2v_sig_err;

  assign sp2v_sig[0] = in_valid_i;
  assign sp2v_sig[1] = out_ready_i;
  assign sp2v_sig[2] = crypt_i;
  assign sp2v_sig[3] = dec_key_gen_i;
  assign sp2v_sig[4] = sp2v_e'(crypt_q_raw);
  assign sp2v_sig[5] = sp2v_e'(dec_key_gen_q_raw);
  assign sp2v_sig[6] = sub_bytes_out_req_i;
  assign sp2v_sig[7] = key_expand_out_req_i;

  // All signals inside sp2v_sig except for sub_bytes/key_expand_out_req_i are driven and consumed
  // by multi-rail FSMs.
  localparam bit [NumSp2VSig-1:0] Sp2VEnSecBuf = 8'b1100_0000;

  // Individually check sparsely encoded signals.
  for (genvar i = 0; i < NumSp2VSig; i++) begin : gen_sel_buf_chk
    aes_sel_buf_chk #(
      .Num      ( Sp2VNum         ),
      .Width    ( Sp2VWidth       ),
      .EnSecBuf ( Sp2VEnSecBuf[i] )
    ) u_aes_sp2v_sig_buf_chk_i (
      .clk_i  ( clk_i               ),
      .rst_ni ( rst_ni              ),
      .sel_i  ( sp2v_sig[i]         ),
      .sel_o  ( sp2v_sig_chk_raw[i] ),
      .err_o  ( sp2v_sig_err[i]     )
    );
    assign sp2v_sig_chk[i] = sp2v_e'(sp2v_sig_chk_raw[i]);
  end

  assign in_valid           = sp2v_sig_chk[0];
  assign out_ready          = sp2v_sig_chk[1];
  assign crypt              = sp2v_sig_chk[2];
  assign dec_key_gen        = sp2v_sig_chk[3];
  assign crypt_q            = sp2v_sig_chk[4];
  assign dec_key_gen_q      = sp2v_sig_chk[5];
  assign sub_bytes_out_req  = sp2v_sig_chk[6];
  assign key_expand_out_req = sp2v_sig_chk[7];

  // Collect encoding errors.
  // We instantiate the checker modules as close as possible to where the sparsely encoded signals
  // are used. Here, we collect also encoding errors detected in other places of the cipher core.
  assign sp_enc_err = |sp2v_sig_err | sp_enc_err_i;

  ////////////////
  // Assertions //
  ////////////////

  // Selectors must be known/valid
  `CALIPTRA_ASSERT(AesCiphOpValid, cfg_valid_i |-> op_i inside {
      CIPH_FWD,
      CIPH_INV
      })

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES cipher core implementation
//
// This module contains the AES cipher core including, state register, full key and decryption key
// registers as well as key expand module and control unit.
//
//
// Masking
// -------
//
// If the parameter "Masking" is set to one, first-order masking is applied to the entire
// cipher core including key expand module. For details, see Rivain et al., "Provably secure
// higher-order masking of AES" available at https://eprint.iacr.org/2010/441.pdf .
//
//
// Details on the data formats
// ---------------------------
//
// This implementation uses 4-dimensional SystemVerilog arrays to represent the AES state:
//
//   logic [3:0][3:0][7:0] state_q [NumShares];
//
// The fourth dimension (unpacked) corresponds to the different shares. The first element holds the
// (masked) data share whereas the other elements hold the masks (masked implementation only).
// The three packed dimensions correspond to the 128-bit state matrix per share. This
// implementation uses the same encoding as the Advanced Encryption Standard (AES) FIPS Publication
// 197 available at https://www.nist.gov/publications/advanced-encryption-standard-aes (see Section
// 3.4). An input sequence of 16 bytes (128-bit, left most byte is the first one)
//
//   b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11 b12 b13 b14 b15
//
// is mapped to the state matrix as
//
//   [ b0  b4  b8  b12 ]
//   [ b1  b5  b9  b13 ]
//   [ b2  b6  b10 b14 ]
//   [ b3  b7  b11 b15 ] .
//
// This is mapped to three packed dimensions of SystemVerilog array as follows:
// - The first dimension corresponds to the rows. Thus, state_q[0] gives
//   - The first row of the state matrix       [ b0   b4  b8  b12 ], or
//   - A 32-bit packed SystemVerilog array 32h'{ b12, b8, b4, b0  }.
//
// - The second dimension corresponds to the columns. To access complete columns, the state matrix
//   must be transposed first. Thus state_transposed = aes_pkg::aes_transpose(state_q) and then
//   state_transposed[1] gives
//   - The second column of the state matrix   [ b4  b5  b6  b7 ], or
//   - A 32-bit packed SystemVerilog array 32h'{ b7, b6, b5, b4 }.
//
// - The third dimension corresponds to the bytes.
//
// Note that the CSRs are little-endian. The input sequence above is provided to 32-bit DATA_IN_0 -
// DATA_IN_3 registers as
//                   MSB            LSB
// - DATA_IN_0 32h'{ b3 , b2 , b1 , b0  }
// - DATA_IN_1 32h'{ b7 , b6 , b4 , b4  }
// - DATA_IN_2 32h'{ b11, b10, b9 , b8  }
// - DATA_IN_3 32h'{ b15, b14, b13, b12 } .
//
// The input state can thus be obtained by transposing the content of the DATA_IN_0 - DATA_IN_3
// registers.
//
// Similarly, the implementation uses a 3-dimensional array to represent the AES keys:
//
//   logic     [7:0][31:0] key_full_q [NumShares]
//
// The third dimension (unpacked) corresponds to the different shares. The first element holds the
// (masked) key share whereas the other elements hold the masks (masked implementation only).
// The two packed dimensions correspond to the 256-bit key per share. This implementation uses
// the same encoding as the Advanced Encryption Standard (AES) FIPS Publication
// 197 available at https://www.nist.gov/publications/advanced-encryption-standard-aes .
//
// The first packed dimension corresponds to the 8 key words. The second packed dimension
// corresponds to the 32 bits per key word. A key sequence of 32 bytes (256-bit, left most byte is
// the first one)
//
//   b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11 b12 b13 b14 b15 ... ... b28 b29 b30 b31
//
// is mapped to the key words and registers (little-endian) as
//                      MSB            LSB
// - KEY_SHARE0_0 32h'{ b3 , b2 , b1 , b0  }
// - KEY_SHARE0_1 32h'{ b7 , b6 , b4 , b4  }
// - KEY_SHARE0_2 32h'{ b11, b10, b9 , b8  }
// - KEY_SHARE0_3 32h'{ b15, b14, b13, b12 }
// - KEY_SHARE0_4 32h'{  .    .    .    .  }
// - KEY_SHARE0_5 32h'{  .    .    .    .  }
// - KEY_SHARE0_6 32h'{  .    .    .    .  }
// - KEY_SHARE0_7 32h'{ b31, b30, b29, b28 } .

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_cipher_core 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit          AES192Enable         = 1,
  parameter bit          SecMasking           = 1,
  parameter sbox_impl_e  SecSBoxImpl          = SBoxImplDom,
  parameter bit          SecAllowForcingMasks = 0,
  parameter bit          SecSkipPRNGReseeding = 0,
  parameter int unsigned EntropyWidth         = edn_pkg::ENDPOINT_BUS_WIDTH,

  localparam int         NumShares            = SecMasking ? 2 : 1, // derived parameter

  parameter masking_lfsr_seed_t RndCnstMaskingLfsrSeed = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t RndCnstMaskingLfsrPerm = RndCnstMaskingLfsrPermDefault
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  // Input handshake signals
  input  sp2v_e                       in_valid_i,
  output sp2v_e                       in_ready_o,

  // Output handshake signals
  output sp2v_e                       out_valid_o,
  input  sp2v_e                       out_ready_i,

  // Control and sync signals
  input  logic                        cfg_valid_i, // Used for gating assertions only.
  input  ciph_op_e                    op_i,
  input  key_len_e                    key_len_i,
  input  sp2v_e                       crypt_i,
  output sp2v_e                       crypt_o,
  input  sp2v_e                       dec_key_gen_i,
  output sp2v_e                       dec_key_gen_o,
  input  logic                        prng_reseed_i,
  output logic                        prng_reseed_o,
  input  logic                        key_clear_i,
  output logic                        key_clear_o,
  input  logic                        data_out_clear_i, // Re-use the cipher core muxes.
  output logic                        data_out_clear_o,
  input  logic                        alert_fatal_i,
  output logic                        alert_o,

  // Pseudo-random data for register clearing
  input  logic [WidthPRDClearing-1:0] prd_clearing_i [NumShares],

  // Masking PRNG
  input  logic                        force_masks_i, // Useful for SCA only.
  output logic        [3:0][3:0][7:0] data_in_mask_o,
  output logic                        entropy_req_o,
  input  logic                        entropy_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_i,

  // I/O data & initial key
  input  logic        [3:0][3:0][7:0] state_init_i [NumShares],
  input  logic            [7:0][31:0] key_init_i [NumShares],
  output logic        [3:0][3:0][7:0] state_o [NumShares]
);

  // Signals
  logic               [3:0][3:0][7:0] state_d [NumShares];
  logic               [3:0][3:0][7:0] state_q [NumShares];
  sp2v_e                              state_we_ctrl;
  sp2v_e                              state_we;
  logic           [StateSelWidth-1:0] state_sel_raw;
  state_sel_e                         state_sel_ctrl;
  state_sel_e                         state_sel;
  logic                               state_sel_err;

  sp2v_e                              sub_bytes_en;
  sp2v_e                              sub_bytes_out_req;
  sp2v_e                              sub_bytes_out_ack;
  logic                               sub_bytes_err;
  logic               [3:0][3:0][7:0] sub_bytes_out;
  logic               [3:0][3:0][7:0] sb_in_mask;
  logic               [3:0][3:0][7:0] sb_out_mask;
  logic               [3:0][3:0][7:0] shift_rows_in [NumShares];
  logic               [3:0][3:0][7:0] shift_rows_out [NumShares];
  logic               [3:0][3:0][7:0] mix_columns_out [NumShares];
  logic               [3:0][3:0][7:0] add_round_key_in [NumShares];
  logic               [3:0][3:0][7:0] add_round_key_out [NumShares];
  logic           [AddRKSelWidth-1:0] add_rk_sel_raw;
  add_rk_sel_e                        add_rk_sel_ctrl;
  add_rk_sel_e                        add_rk_sel;
  logic                               add_rk_sel_err;

  logic                   [7:0][31:0] key_full_d [NumShares];
  logic                   [7:0][31:0] key_full_q [NumShares];
  sp2v_e                              key_full_we_ctrl;
  sp2v_e                              key_full_we;
  logic         [KeyFullSelWidth-1:0] key_full_sel_raw;
  key_full_sel_e                      key_full_sel_ctrl;
  key_full_sel_e                      key_full_sel;
  logic                               key_full_sel_err;
  logic                   [7:0][31:0] key_dec_d [NumShares];
  logic                   [7:0][31:0] key_dec_q [NumShares];
  sp2v_e                              key_dec_we_ctrl;
  sp2v_e                              key_dec_we;
  logic          [KeyDecSelWidth-1:0] key_dec_sel_raw;
  key_dec_sel_e                       key_dec_sel_ctrl;
  key_dec_sel_e                       key_dec_sel;
  logic                               key_dec_sel_err;
  logic                   [7:0][31:0] key_expand_out [NumShares];
  ciph_op_e                           key_expand_op;
  sp2v_e                              key_expand_en;
  sp2v_e                              key_expand_out_req;
  sp2v_e                              key_expand_out_ack;
  logic                               key_expand_err;
  logic                               key_expand_clear;
  logic                         [3:0] key_expand_round;
  logic        [KeyWordsSelWidth-1:0] key_words_sel_raw;
  key_words_sel_e                     key_words_sel_ctrl;
  key_words_sel_e                     key_words_sel;
  logic                               key_words_sel_err;
  logic                   [3:0][31:0] key_words [NumShares];
  logic               [3:0][3:0][7:0] key_bytes [NumShares];
  logic               [3:0][3:0][7:0] key_mix_columns_out [NumShares];
  logic               [3:0][3:0][7:0] round_key [NumShares];
  logic        [RoundKeySelWidth-1:0] round_key_sel_raw;
  round_key_sel_e                     round_key_sel_ctrl;
  round_key_sel_e                     round_key_sel;
  logic                               round_key_sel_err;

  logic                               cfg_valid;
  logic                               mux_sel_err;
  logic                               sp_enc_err_d, sp_enc_err_q;
  logic                               op_err;

  // Pseudo-random data for clearing and masking purposes
  logic                       [127:0] prd_clearing_128 [NumShares];
  logic                       [255:0] prd_clearing_256 [NumShares];

  logic         [WidthPRDMasking-1:0] prd_masking;
  logic  [3:0][3:0][WidthPRDSBox-1:0] prd_sub_bytes;
  logic             [WidthPRDKey-1:0] prd_key_expand;
  logic                               prd_masking_upd;
  logic                               prd_masking_rsd_req;
  logic                               prd_masking_rsd_ack;

  // Generate clearing signals of appropriate widths. If masking is enabled, the two shares of
  // the registers must be cleared with different pseudo-random data.
  for (genvar s = 0; s < NumShares; s++) begin : gen_prd_clearing_shares
    for (genvar c = 0; c < NumChunksPRDClearing128; c++) begin : gen_prd_clearing_128
      assign prd_clearing_128[s][c * WidthPRDClearing +: WidthPRDClearing] = prd_clearing_i[s];
    end
    for (genvar c = 0; c < NumChunksPRDClearing256; c++) begin : gen_prd_clearing_256
      assign prd_clearing_256[s][c * WidthPRDClearing +: WidthPRDClearing] = prd_clearing_i[s];
    end
  end

  // op_i is one-hot encoded. Check the provided value and trigger an alert upon detecing invalid
  // encodings.
  assign op_err    = ~(op_i == CIPH_FWD || op_i == CIPH_INV);
  assign cfg_valid = cfg_valid_i & ~op_err;

  //////////
  // Data //
  //////////

  // SEC_CM: DATA_REG.SEC_WIPE
  // State registers
  always_comb begin : state_mux
    unique case (state_sel)
      STATE_INIT:  state_d = state_init_i;
      STATE_ROUND: state_d = add_round_key_out;
      STATE_CLEAR: state_d = prd_clearing_128;
      default:     state_d = prd_clearing_128;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : state_reg
    if (!rst_ni) begin
      state_q <= '{default: '0};
    end else if (state_we == SP2V_HIGH) begin
      state_q <= state_d;
    end
  end

  // Masking
  if (!SecMasking) begin : gen_no_masks
    // The masks are ignored anyway, they can be 0.
    assign sb_in_mask  = '0;
    assign prd_masking = '0;

    // Tie-off unused signals.
    logic unused_entropy_ack;
    logic [EntropyWidth-1:0] unused_entropy;
    assign unused_entropy_ack = entropy_ack_i;
    assign unused_entropy     = entropy_i;
    assign entropy_req_o      = 1'b0;

    logic unused_force_masks;
    logic unused_prd_masking_upd;
    logic unused_prd_masking_rsd_req;
    assign unused_force_masks         = force_masks_i;
    assign unused_prd_masking_upd     = prd_masking_upd;
    assign unused_prd_masking_rsd_req = prd_masking_rsd_req;
    assign prd_masking_rsd_ack        = 1'b0;

    logic [3:0][3:0][7:0] unused_sb_out_mask;
    assign unused_sb_out_mask = sb_out_mask;

  end else begin : gen_masks
    // The input mask is the mask share of the state.
    assign sb_in_mask  = state_q[1];

    // The masking PRNG generates:
    // - the pseudo-random data (PRD) required by SubBytes,
    // - the PRD required by the key expand module (has 4 S-Boxes internally).
    aes_prng_masking #(
      .Width                ( WidthPRDMasking        ),
      .ChunkSize            ( ChunkSizePRDMasking    ),
      .EntropyWidth         ( EntropyWidth           ),
      .SecAllowForcingMasks ( SecAllowForcingMasks   ),
      .SecSkipPRNGReseeding ( SecSkipPRNGReseeding   ),
      .RndCnstLfsrSeed      ( RndCnstMaskingLfsrSeed ),
      .RndCnstLfsrPerm      ( RndCnstMaskingLfsrPerm )
    ) u_aes_prng_masking (
      .clk_i         ( clk_i               ),
      .rst_ni        ( rst_ni              ),
      .force_masks_i ( force_masks_i       ),
      .data_update_i ( prd_masking_upd     ),
      .data_o        ( prd_masking         ),
      .reseed_req_i  ( prd_masking_rsd_req ),
      .reseed_ack_o  ( prd_masking_rsd_ack ),
      .entropy_req_o ( entropy_req_o       ),
      .entropy_ack_i ( entropy_ack_i       ),
      .entropy_i     ( entropy_i           )
    );
  end

  // Extract randomness for key expand module and SubBytes.
  //
  // The masking PRNG output has the following shape:
  // prd_masking = { prd_key_expand, prd_sub_bytes }
  assign prd_key_expand = prd_masking[WidthPRDMasking-1 -: WidthPRDKey];
  assign prd_sub_bytes  = prd_masking[WidthPRDData-1 -: WidthPRDData];

  // Extract randomness for masking the input data.
  //
  // The masking PRNG is used for generating both the PRD for the S-Boxes/SubBytes operation as
  // well as for the input data masks. When using any of the masked Canright S-Box implementations,
  // it is important that the SubBytes input masks (generated by the PRNG in Round X-1) and the
  // SubBytes output masks (generated by the PRNG in Round X) are independent. Inside the PRNG,
  // this is achieved by using multiple, separately re-seeded LFSR chunks and by selecting the
  // separate LFSR chunks in alternating fashion. Since the input data masks become the SubBytes
  // input masks in the first round, we select the same 8 bit lanes for the input data masks which
  // are also used to form the SubBytes output mask for the masked Canright S-Box implementations,
  // i.e., the 8 LSBs of the per S-Box PRD. In particular, we have:
  //
  // prd_masking = { prd_key_expand, ... , sb_prd[4], sb_out_mask[4], sb_prd[0], sb_out_mask[0] }
  //
  // Where sb_out_mask[x] contains the SubBytes output mask for byte x (when using a masked
  // Canright S-Box implementation) and sb_prd[x] contains additional PRD consumed by SubBytes for
  // byte x.
  //
  // When using a masked S-Box implementation other than Canright, we still select the 8 LSBs of
  // the per-S-Box PRD to form the input data mask of the corresponding byte. We do this to
  // distribute the input data masks over all LFSR chunks of the masking PRNG. We do the extraction
  // on a row basis.
  localparam int unsigned WidthPRDRow = 4*WidthPRDSBox;
  for (genvar i = 0; i < 4; i++) begin : gen_in_mask
    assign data_in_mask_o[i] = aes_prd_get_lsbs(prd_masking[i * WidthPRDRow +: WidthPRDRow]);
  end

  // Cipher data path
  aes_sub_bytes #(
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_sub_bytes (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .en_i      ( sub_bytes_en      ),
    .out_req_o ( sub_bytes_out_req ),
    .out_ack_i ( sub_bytes_out_ack ),
    .op_i      ( op_i              ),
    .data_i    ( state_q[0]        ),
    .mask_i    ( sb_in_mask        ),
    .prd_i     ( prd_sub_bytes     ),
    .data_o    ( sub_bytes_out     ),
    .mask_o    ( sb_out_mask       ),
    .err_o     ( sub_bytes_err     )
  );

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_shift_mix
    if (s == 0) begin : gen_shift_in_data
      // The (masked) data share
      assign shift_rows_in[s] = sub_bytes_out;
    end else begin : gen_shift_in_mask
      // The mask share
      assign shift_rows_in[s] = sb_out_mask;
    end

    aes_shift_rows u_aes_shift_rows (
      .op_i   ( op_i              ),
      .data_i ( shift_rows_in[s]  ),
      .data_o ( shift_rows_out[s] )
    );

    aes_mix_columns u_aes_mix_columns (
      .op_i   ( op_i               ),
      .data_i ( shift_rows_out[s]  ),
      .data_o ( mix_columns_out[s] )
    );
  end

  always_comb begin : add_round_key_in_mux
    unique case (add_rk_sel)
      ADD_RK_INIT:  add_round_key_in = state_q;
      ADD_RK_ROUND: add_round_key_in = mix_columns_out;
      ADD_RK_FINAL: add_round_key_in = shift_rows_out;
      default:      add_round_key_in = state_q;
    endcase
  end

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_add_round_key
    assign add_round_key_out[s] = add_round_key_in[s] ^ round_key[s];
  end

  /////////
  // Key //
  /////////

  // SEC_CM: KEY.SEC_WIPE
  // Full Key registers
  always_comb begin : key_full_mux
    unique case (key_full_sel)
      KEY_FULL_ENC_INIT: key_full_d = key_init_i;
      KEY_FULL_DEC_INIT: key_full_d = key_dec_q;
      KEY_FULL_ROUND:    key_full_d = key_expand_out;
      KEY_FULL_CLEAR:    key_full_d = prd_clearing_256;
      default:           key_full_d = prd_clearing_256;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : key_full_reg
    if (!rst_ni) begin
      key_full_q <= '{default: '0};
    end else if (key_full_we == SP2V_HIGH) begin
      key_full_q <= key_full_d;
    end
  end

  // SEC_CM: KEY.SEC_WIPE
  // Decryption Key registers
  always_comb begin : key_dec_mux
    unique case (key_dec_sel)
      KEY_DEC_EXPAND: key_dec_d = key_expand_out;
      KEY_DEC_CLEAR:  key_dec_d = prd_clearing_256;
      default:        key_dec_d = prd_clearing_256;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : key_dec_reg
    if (!rst_ni) begin
      key_dec_q <= '{default: '0};
    end else if (key_dec_we == SP2V_HIGH) begin
      key_dec_q <= key_dec_d;
    end
  end

  // Key expand data path
  aes_key_expand #(
    .AES192Enable ( AES192Enable ),
    .SecMasking   ( SecMasking   ),
    .SecSBoxImpl  ( SecSBoxImpl  )
  ) u_aes_key_expand (
    .clk_i       ( clk_i              ),
    .rst_ni      ( rst_ni             ),
    .cfg_valid_i ( cfg_valid          ),
    .op_i        ( key_expand_op      ),
    .en_i        ( key_expand_en      ),
    .out_req_o   ( key_expand_out_req ),
    .out_ack_i   ( key_expand_out_ack ),
    .clear_i     ( key_expand_clear   ),
    .round_i     ( key_expand_round   ),
    .key_len_i   ( key_len_i          ),
    .key_i       ( key_full_q         ),
    .key_o       ( key_expand_out     ),
    .prd_i       ( prd_key_expand     ),
    .err_o       ( key_expand_err     )
  );

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_round_key
    always_comb begin : key_words_mux
      unique case (key_words_sel)
        KEY_WORDS_0123: key_words[s] = key_full_q[s][3:0];
        KEY_WORDS_2345: key_words[s] = AES192Enable ? key_full_q[s][5:2] : '0;
        KEY_WORDS_4567: key_words[s] = key_full_q[s][7:4];
        KEY_WORDS_ZERO: key_words[s] = '0;
        default:        key_words[s] = '0;
      endcase
    end

    // Convert words to bytes (every key word contains one column).
    assign key_bytes[s] = aes_transpose(key_words[s]);

    aes_mix_columns u_aes_key_mix_columns (
      .op_i   ( CIPH_INV               ),
      .data_i ( key_bytes[s]           ),
      .data_o ( key_mix_columns_out[s] )
    );
  end

  always_comb begin : round_key_mux
    unique case (round_key_sel)
      ROUND_KEY_DIRECT: round_key = key_bytes;
      ROUND_KEY_MIXED:  round_key = key_mix_columns_out;
      default:          round_key = key_bytes;
    endcase
  end

  /////////////
  // Control //
  /////////////

  // Control
  aes_cipher_control #(
    .SecMasking  ( SecMasking  ),
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_cipher_control (
    .clk_i                ( clk_i               ),
    .rst_ni               ( rst_ni              ),

    .in_valid_i           ( in_valid_i          ),
    .in_ready_o           ( in_ready_o          ),

    .out_valid_o          ( out_valid_o         ),
    .out_ready_i          ( out_ready_i         ),

    .cfg_valid_i          ( cfg_valid           ),
    .op_i                 ( op_i                ),
    .key_len_i            ( key_len_i           ),
    .crypt_i              ( crypt_i             ),
    .crypt_o              ( crypt_o             ),
    .dec_key_gen_i        ( dec_key_gen_i       ),
    .dec_key_gen_o        ( dec_key_gen_o       ),
    .prng_reseed_i        ( prng_reseed_i       ),
    .prng_reseed_o        ( prng_reseed_o       ),
    .key_clear_i          ( key_clear_i         ),
    .key_clear_o          ( key_clear_o         ),
    .data_out_clear_i     ( data_out_clear_i    ),
    .data_out_clear_o     ( data_out_clear_o    ),
    .mux_sel_err_i        ( mux_sel_err         ),
    .sp_enc_err_i         ( sp_enc_err_q        ),
    .op_err_i             ( op_err              ),
    .alert_fatal_i        ( alert_fatal_i       ),
    .alert_o              ( alert_o             ),

    .prng_update_o        ( prd_masking_upd     ),
    .prng_reseed_req_o    ( prd_masking_rsd_req ),
    .prng_reseed_ack_i    ( prd_masking_rsd_ack ),

    .state_sel_o          ( state_sel_ctrl      ),
    .state_we_o           ( state_we_ctrl       ),
    .sub_bytes_en_o       ( sub_bytes_en        ),
    .sub_bytes_out_req_i  ( sub_bytes_out_req   ),
    .sub_bytes_out_ack_o  ( sub_bytes_out_ack   ),
    .add_rk_sel_o         ( add_rk_sel_ctrl     ),

    .key_expand_op_o      ( key_expand_op       ),
    .key_full_sel_o       ( key_full_sel_ctrl   ),
    .key_full_we_o        ( key_full_we_ctrl    ),
    .key_dec_sel_o        ( key_dec_sel_ctrl    ),
    .key_dec_we_o         ( key_dec_we_ctrl     ),
    .key_expand_en_o      ( key_expand_en       ),
    .key_expand_out_req_i ( key_expand_out_req  ),
    .key_expand_out_ack_o ( key_expand_out_ack  ),
    .key_expand_clear_o   ( key_expand_clear    ),
    .key_expand_round_o   ( key_expand_round    ),
    .key_words_sel_o      ( key_words_sel_ctrl  ),
    .round_key_sel_o      ( round_key_sel_ctrl  )
  );

  ///////////////
  // Selectors //
  ///////////////

  // We use sparse encodings for these mux selector signals and must ensure that:
  // 1. The synthesis tool doesn't optimize away the sparse encoding.
  // 2. The selector signal is always valid. More precisely, an alert or SVA is triggered if a
  //    selector signal takes on an invalid value.
  // 3. The alert signal remains asserted until reset even if the selector signal becomes valid
  //    again. This is achieved by driving the control FSM into the terminal error state whenever
  //    any mux selector signal becomes invalid.
  //
  // If any mux selector signal becomes invalid, the cipher core further immediately de-asserts
  // the out_valid_o signal to prevent any data from being released.

  aes_sel_buf_chk #(
    .Num      ( StateSelNum   ),
    .Width    ( StateSelWidth ),
    .EnSecBuf ( 1'b1          )
  ) u_aes_state_sel_buf_chk (
    .clk_i  ( clk_i          ),
    .rst_ni ( rst_ni         ),
    .sel_i  ( state_sel_ctrl ),
    .sel_o  ( state_sel_raw  ),
    .err_o  ( state_sel_err  )
  );
  assign state_sel = state_sel_e'(state_sel_raw);

  aes_sel_buf_chk #(
    .Num      ( AddRKSelNum   ),
    .Width    ( AddRKSelWidth ),
    .EnSecBuf ( 1'b1          )
  ) u_aes_add_rk_sel_buf_chk (
    .clk_i  ( clk_i           ),
    .rst_ni ( rst_ni          ),
    .sel_i  ( add_rk_sel_ctrl ),
    .sel_o  ( add_rk_sel_raw  ),
    .err_o  ( add_rk_sel_err  )
  );
  assign add_rk_sel = add_rk_sel_e'(add_rk_sel_raw);

  aes_sel_buf_chk #(
    .Num      ( KeyFullSelNum   ),
    .Width    ( KeyFullSelWidth ),
    .EnSecBuf ( 1'b1            )
  ) u_aes_key_full_sel_buf_chk (
    .clk_i  ( clk_i             ),
    .rst_ni ( rst_ni            ),
    .sel_i  ( key_full_sel_ctrl ),
    .sel_o  ( key_full_sel_raw  ),
    .err_o  ( key_full_sel_err  )
  );
  assign key_full_sel = key_full_sel_e'(key_full_sel_raw);

  aes_sel_buf_chk #(
    .Num      ( KeyDecSelNum   ),
    .Width    ( KeyDecSelWidth ),
    .EnSecBuf ( 1'b1           )
  ) u_aes_key_dec_sel_buf_chk (
    .clk_i  ( clk_i            ),
    .rst_ni ( rst_ni           ),
    .sel_i  ( key_dec_sel_ctrl ),
    .sel_o  ( key_dec_sel_raw  ),
    .err_o  ( key_dec_sel_err  )
  );
  assign key_dec_sel = key_dec_sel_e'(key_dec_sel_raw);

  aes_sel_buf_chk #(
    .Num      ( KeyWordsSelNum   ),
    .Width    ( KeyWordsSelWidth ),
    .EnSecBuf ( 1'b1             )
  ) u_aes_key_words_sel_buf_chk (
    .clk_i  ( clk_i              ),
    .rst_ni ( rst_ni             ),
    .sel_i  ( key_words_sel_ctrl ),
    .sel_o  ( key_words_sel_raw  ),
    .err_o  ( key_words_sel_err  )
  );
  assign key_words_sel = key_words_sel_e'(key_words_sel_raw);

  aes_sel_buf_chk #(
    .Num      ( RoundKeySelNum   ),
    .Width    ( RoundKeySelWidth ),
    .EnSecBuf ( 1'b1             )
  ) u_aes_round_key_sel_buf_chk (
    .clk_i  ( clk_i              ),
    .rst_ni ( rst_ni             ),
    .sel_i  ( round_key_sel_ctrl ),
    .sel_o  ( round_key_sel_raw  ),
    .err_o  ( round_key_sel_err  )
  );
  assign round_key_sel = round_key_sel_e'(round_key_sel_raw);

  // Signal invalid mux selector signals to control FSM which will lock up and trigger an alert.
  assign mux_sel_err = state_sel_err | add_rk_sel_err | key_full_sel_err |
      key_dec_sel_err | key_words_sel_err | round_key_sel_err;

  //////////////////////////////
  // Sparsely Encoded Signals //
  //////////////////////////////

  // We use sparse encodings for various critical signals and must ensure that:
  // 1. The synthesis tool doesn't optimize away the sparse encoding.
  // 2. The sparsely encoded signal is always valid. More precisely, an alert or SVA is triggered
  //    if a sparse signal takes on an invalid value.
  // 3. The alert signal remains asserted until reset even if the sparse signal becomes valid again
  //    This is achieved by driving the control FSM into the terminal error state whenever any
  //    sparsely encoded signal becomes invalid.
  //
  // If any sparsely encoded signal becomes invalid, the cipher core further immediately de-asserts
  // the out_valid_o signal to prevent any data from being released.

  // We use vectors of sparsely encoded signals to reduce code duplication.
  localparam int unsigned NumSp2VSig = 3;
  sp2v_e [NumSp2VSig-1:0]                sp2v_sig;
  sp2v_e [NumSp2VSig-1:0]                sp2v_sig_chk;
  logic  [NumSp2VSig-1:0][Sp2VWidth-1:0] sp2v_sig_chk_raw;
  logic  [NumSp2VSig-1:0]                sp2v_sig_err;

  assign sp2v_sig[0] = state_we_ctrl;
  assign sp2v_sig[1] = key_full_we_ctrl;
  assign sp2v_sig[2] = key_dec_we_ctrl;

  // All signals inside sp2v_sig are eventually converted to single-rail signals.
  localparam bit [NumSp2VSig-1:0] Sp2VEnSecBuf = {NumSp2VSig{1'b1}};

  // Individually check sparsely encoded signals.
  for (genvar i = 0; i < NumSp2VSig; i++) begin : gen_sel_buf_chk
    aes_sel_buf_chk #(
      .Num      ( Sp2VNum         ),
      .Width    ( Sp2VWidth       ),
      .EnSecBuf ( Sp2VEnSecBuf[i] )
    ) u_aes_sp2v_sig_buf_chk_i (
      .clk_i  ( clk_i               ),
      .rst_ni ( rst_ni              ),
      .sel_i  ( sp2v_sig[i]         ),
      .sel_o  ( sp2v_sig_chk_raw[i] ),
      .err_o  ( sp2v_sig_err[i]     )
    );
    assign sp2v_sig_chk[i] = sp2v_e'(sp2v_sig_chk_raw[i]);
  end

  assign state_we    = sp2v_sig_chk[0];
  assign key_full_we = sp2v_sig_chk[1];
  assign key_dec_we  = sp2v_sig_chk[2];

  // Collect encoding errors.
  // We instantiate the checker modules as close as possible to where the sparsely encoded signals
  // are used. Here, we collect also encoding errors detected in other places of the cipher core.
  assign sp_enc_err_d = |sp2v_sig_err | sub_bytes_err | key_expand_err;

  // We need to register the collected error signal to avoid circular loops in the cipher core
  // controller related to out_valid_o and detecting errors in state_we_o and sub_bytes_out_ack.
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_sp_enc_err
    if (!rst_ni) begin
      sp_enc_err_q <= 1'b0;
    end else if (sp_enc_err_d) begin
      sp_enc_err_q <= 1'b1;
    end
  end

  /////////////
  // Outputs //
  /////////////

  // The output of the last round is not stored into the state register but forwarded directly.
  assign state_o = add_round_key_out;

  ////////////////
  // Assertions //
  ////////////////

// Typically assertions already contain this macro, which ensures that assertions are only compiled
// in simulation and FPV. However, we wrap the entire assertion section with INC_ASSERT so that the
// helper logic below is not synthesized either, since that could cause issues in DC.
`ifdef INC_ASSERT
  //VCS coverage off
  // pragma coverage off

  // Create a lint error to reduce the risk of accidentally disabling the masking.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesSecMaskingNonDefault, SecMasking == 1)

  // Cipher core masking requires a masked SBox and vice versa.
  `CALIPTRA_ASSERT_INIT(AesMaskedCoreAndSBox,
      (SecMasking &&
      (SecSBoxImpl == SBoxImplCanrightMasked ||
       SecSBoxImpl == SBoxImplCanrightMaskedNoreuse ||
       SecSBoxImpl == SBoxImplDom)) ||
      (!SecMasking &&
      (SecSBoxImpl == SBoxImplLut ||
       SecSBoxImpl == SBoxImplCanright)))

  // Signals used for assertions only.
  logic prd_clearing_equals_output, unused_prd_clearing_equals_output;
  assign prd_clearing_equals_output = (prd_clearing_128 == add_round_key_out);
  assign unused_prd_clearing_equals_output = prd_clearing_equals_output;

  // Ensure that the state register gets cleared with pseudo-random data at the end of the last
  // round. The following two scenarios are unlikely but not illegal:
  // 1. The newly loaded initial state matches the previous output (the round counter is only
  //    cleared upon loading the new initial state).
  // 2. The previous pseudo-random data is equal to the previous output.
  // Otherwise, we must see an alert e.g. because the state multiplexer got glitched.
  `CALIPTRA_ASSERT(AesSecCmDataRegKeySca, (state_we == SP2V_HIGH) &&
      ((key_len_i == AES_128 && u_aes_cipher_control.rnd_ctr == 4'd10) ||
       (key_len_i == AES_192 && u_aes_cipher_control.rnd_ctr == 4'd12) ||
       (key_len_i == AES_256 && u_aes_cipher_control.rnd_ctr == 4'd14)) |=>
      (state_q != $past(add_round_key_out)) ||
      (state_q == $past(state_init_i)) ||
      $past(prd_clearing_equals_output) || alert_o)

  if (SecMasking) begin : gen_sec_cm_key_masking_svas
      // The number of clock cycles a regular AES round takes - only used for assertions.
      localparam int unsigned NumCyclesPerRound = (SecSBoxImpl == SBoxImplDom) ? 5 : 1;
      logic unused_param;
      assign unused_param = (NumCyclesPerRound == 1);
      // Ensure that SubBytes gets fresh PRD input for every evaluation unless mask forcing is
      // enabled. We effectively check that the PRNG has been updated at least once within the
      // last NumCyclesPerRound cycles. This also holds for the very first round, as the PRNG
      // is always updated in the last cycle of the IDLE state and/or the first cycle of the
      // INIT state.
      `CALIPTRA_ASSERT(AesSecCmKeyMaskingPrdSubBytes,
          sub_bytes_en == SP2V_HIGH && ($past(sub_bytes_en) == SP2V_LOW ||
              ($past(sub_bytes_out_req) == SP2V_HIGH &&
               $past(sub_bytes_out_ack) == SP2V_HIGH)) |=>
          $past(prd_sub_bytes) != $past(prd_sub_bytes, NumCyclesPerRound + 1) ||
          SecAllowForcingMasks && force_masks_i)

      // Ensure that the PRNG has been updated between masking the input and starting the first
      // SubBytes evaluation/KeyExpand operation unless mask forcing is enabled. For AES-256,
      // we just spend 1 cycle in the INIT state and KeyExpand isn't evaluating its S-Boxes,
      // i.e., no fresh randomness is required. For the other key lengths, KeyExpand evaluates
      // its S-Boxes which takes NumCyclesPerRound cycles. When computing the start key for
      // decryption, the input isn't loaded and the PRNG is thus not advanced.
      `CALIPTRA_ASSERT(AesSecCmKeyMaskingInitialPrngUpdateSubBytes,
          sub_bytes_en == SP2V_HIGH && $past(sub_bytes_en) == SP2V_LOW |=>
          (key_len_i == AES_256 &&
              $past(prd_masking) != $past(prd_masking, 3)) ||
          ((key_len_i == AES_128 || key_len_i == AES_192) &&
              $past(prd_masking) != $past(prd_masking, NumCyclesPerRound + 2)) ||
          (SecAllowForcingMasks && force_masks_i))
      `CALIPTRA_ASSERT(AesSecCmKeyMaskingInitialPrngUpdateKeyExpand,
          key_expand_en == SP2V_HIGH && $past(key_expand_en) == SP2V_LOW |=>
          (key_len_i == AES_256 &&
              $past(prd_masking) != $past(prd_masking, 3)) ||
          ((key_len_i == AES_128 || key_len_i == AES_192) &&
              $past(prd_masking) != $past(prd_masking, 2)) ||
          (SecAllowForcingMasks && force_masks_i) || dec_key_gen_o == SP2V_HIGH)

      // Ensure none of the state shares keeps being constant during encryption/decryption
      // unless mask forcing is enabled. Even though unlikely it's not impossible that one
      // share remains constant throughout one round. The SVAs thus only fire if a share
      // remains constant across two rounds.
      for (genvar s = 0; s < NumShares; s++) begin : gen_sec_cm_key_masking_share_svas
        `CALIPTRA_ASSERT(AesSecCmKeyMaskingStateShare, state_we == SP2V_HIGH &&
            (crypt_i == SP2V_HIGH || crypt_o == SP2V_HIGH) |=>
            state_q[s] != $past(state_q[s], NumCyclesPerRound) ||
            $past(state_q[s], NumCyclesPerRound) != $past(state_q[s], 2*NumCyclesPerRound) ||
            (SecAllowForcingMasks && force_masks_i) || dec_key_gen_o == SP2V_HIGH)
        `CALIPTRA_ASSERT(AesSecCmKeyMaskingOutputShare,
            (out_valid_o == SP2V_HIGH && $past(out_valid_o) == SP2V_LOW) &&
            (crypt_o == SP2V_HIGH) |=>
            $past(state_o[s]) != $past(state_q[s], NumCyclesPerRound) ||
            $past(state_q[s], NumCyclesPerRound) != $past(state_q[s], 2*NumCyclesPerRound) ||
            (SecAllowForcingMasks && force_masks_i) || dec_key_gen_o == SP2V_HIGH)
      end
  end

  // Make sure the output of the masking PRNG is properly extracted without creating overlaps
  // in the data input masks, or between the PRD fed to the key expand module and SubBytes.
  if (WidthPRDSBox > 8) begin : gen_prd_extract_assert
    // For one row of the state matrix, extract the WidthPRDSBox-8 MSBs of the per-S-Box PRD from
    // the PRNG output.
    function automatic logic [3:0][(WidthPRDSBox-8)-1:0] aes_prd_get_msbs(
      logic [(4*WidthPRDSBox)-1:0] in
    );
      logic [3:0][(WidthPRDSBox-8)-1:0] prd_msbs;
      for (int i = 0; i < 4; i++) begin
        prd_msbs[i] = in[(i*WidthPRDSBox) + 8 +: (WidthPRDSBox-8)];
      end
      return prd_msbs;
    endfunction

    // For one row of the state matrix, undo the extraction of LSBs and MSBs of the per-S-Box PRD
    // from the PRNG output. This can be used to verify proper extraction (no overlap of output
    // masks and PRD for masked Canright S-Box implementations, no unused PRNG output).
    function automatic logic [4*WidthPRDSBox-1:0] aes_prd_concat_bits(
      logic [3:0]                 [7:0] prd_lsbs,
      logic [3:0][(WidthPRDSBox-8)-1:0] prd_msbs
    );
      logic [(4*WidthPRDSBox)-1:0] prd;
      for (int i = 0; i < 4; i++) begin
        prd[(i*WidthPRDSBox) +: WidthPRDSBox] = {prd_msbs[i], prd_lsbs[i]};
      end
      return prd;
    endfunction

    // Check for correct extraction of masking PRNG output without overlaps.
    logic            [WidthPRDMasking-1:0] unused_prd_masking;
    logic [3:0][3:0][(WidthPRDSBox-8)-1:0] unused_prd_msbs;
    for (genvar i = 0; i < 4; i++) begin : gen_unused_prd_msbs
      assign unused_prd_msbs[i] = aes_prd_get_msbs(prd_masking[i * WidthPRDRow +: WidthPRDRow]);
    end
    for (genvar i = 0; i < 4; i++) begin : gen_unused_prd_masking
      assign unused_prd_masking[i * WidthPRDRow +: WidthPRDRow] =
          aes_prd_concat_bits(data_in_mask_o[i], unused_prd_msbs[i]);
    end
    assign unused_prd_masking[WidthPRDMasking-1 -: WidthPRDKey] = prd_key_expand;
    `CALIPTRA_ASSERT(AesMskgPrdExtraction, prd_masking == unused_prd_masking)
  end
  //VCS coverage on
  // pragma coverage on
`endif

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES KeyExpand

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_key_expand 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter bit         AES192Enable = 1,
  parameter bit         SecMasking   = 0,
  parameter sbox_impl_e SecSBoxImpl  = SBoxImplLut,

  localparam int        NumShares    = SecMasking ? 2 : 1 // derived parameter
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   cfg_valid_i,
  input  ciph_op_e               op_i,
  input  sp2v_e                  en_i,
  output sp2v_e                  out_req_o,
  input  sp2v_e                  out_ack_i,
  input  logic                   clear_i,
  input  logic             [3:0] round_i,
  input  key_len_e               key_len_i,
  input  logic       [7:0][31:0] key_i [NumShares],
  output logic       [7:0][31:0] key_o [NumShares],
  input  logic [WidthPRDKey-1:0] prd_i,
  output logic                   err_o
);

  sp2v_e            en;
  logic             en_err;
  sp2v_e            out_ack;
  logic             out_ack_err;

  logic       [7:0] rcon_d, rcon_q;
  logic             rcon_we;
  logic             use_rcon;

  logic       [3:0] rnd;
  logic       [3:0] rnd_type;

  logic      [31:0] spec_in_128 [NumShares];
  logic      [31:0] spec_in_192 [NumShares];
  logic      [31:0] rot_word_in [NumShares];
  logic      [31:0] rot_word_out [NumShares];
  logic             use_rot_word;
  logic      [31:0] sub_word_in, sub_word_out;
  logic       [3:0] sub_word_out_req;
  logic      [31:0] sw_in_mask, sw_out_mask;
  logic       [7:0] rcon_add_in, rcon_add_out;
  logic      [31:0] rcon_added;

  logic      [31:0] irregular [NumShares];
  logic [7:0][31:0] regular [NumShares];

  // cfg_valid_i is used for gating assertions only.
  logic                     unused_cfg_valid;
  assign unused_cfg_valid = cfg_valid_i;

  // Get a shorter reference.
  assign rnd = round_i;

  // For AES-192, there are four different types of rounds.
  always_comb begin : get_rnd_type
    if (AES192Enable) begin
      rnd_type[0] = (rnd == 0);
      rnd_type[1] = (rnd == 1 || rnd == 4 || rnd == 7 || rnd == 10);
      rnd_type[2] = (rnd == 2 || rnd == 5 || rnd == 8 || rnd == 11);
      rnd_type[3] = (rnd == 3 || rnd == 6 || rnd == 9 || rnd == 12);
    end else begin
      rnd_type = '0;
    end
  end

  //////////////////////////////////////////////////////
  // Irregular part involving Rcon, RotWord & SubWord //
  //////////////////////////////////////////////////////

  // Depending on key length and round, RotWord may not be used.
  assign use_rot_word = (key_len_i == AES_256 && rnd[0] == 1'b0) ? 1'b0 : 1'b1;

  // Depending on operation, key length and round, Rcon may not be used thus must not be updated.
  always_comb begin : rcon_usage
    use_rcon = 1'b1;

    if (AES192Enable) begin
      if (key_len_i == AES_192 &&
          ((op_i == CIPH_FWD &&  rnd_type[1]) ||
           (op_i == CIPH_INV && (rnd_type[0] || rnd_type[3])))) begin
        use_rcon = 1'b0;
      end
    end

    if (key_len_i == AES_256 && rnd[0] == 1'b0) begin
      use_rcon = 1'b0;
    end
  end

  // Generate Rcon
  always_comb begin : rcon_update
    rcon_d = rcon_q;

    if (clear_i) begin
      rcon_d = (op_i == CIPH_FWD)                            ? 8'h01 :
              ((op_i == CIPH_INV) && (key_len_i == AES_128)) ? 8'h36 :
              ((op_i == CIPH_INV) && (key_len_i == AES_192)) ? 8'h80 :
              ((op_i == CIPH_INV) && (key_len_i == AES_256)) ? 8'h40 : 8'h01;
    end else begin
      rcon_d = (op_i == CIPH_FWD) ? aes_mul2(rcon_q) :
               (op_i == CIPH_INV) ? aes_div2(rcon_q) : 8'h01;
    end
  end

  // Advance.
  assign rcon_we = clear_i | use_rcon &
      (en == SP2V_HIGH) & (out_req_o == SP2V_HIGH) & (out_ack == SP2V_HIGH);

  // Rcon register
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_rcon
    if (!rst_ni) begin
      rcon_q <= '0;
    end else if (rcon_we) begin
      rcon_q <= rcon_d;
    end
  end

  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_rot_word_out
    // Special input, equivalent to key_o[3] in the used cases
    assign spec_in_128[s] = key_i[s][3] ^ key_i[s][2];
    assign spec_in_192[s] = AES192Enable ? key_i[s][5] ^ key_i[s][1] ^ key_i[s][0] : '0;

    // Select input
    always_comb begin : rot_word_in_mux
      unique case (key_len_i)

        /////////////
        // AES-128 //
        /////////////
        AES_128: begin
          unique case (op_i)
            CIPH_FWD: rot_word_in[s] = key_i[s][3];
            CIPH_INV: rot_word_in[s] = spec_in_128[s];
            default:  rot_word_in[s] = key_i[s][3];
          endcase
        end

        /////////////
        // AES-192 //
        /////////////
        AES_192: begin
          if (AES192Enable) begin
            unique case (op_i)
              CIPH_FWD: begin
                rot_word_in[s] = rnd_type[0] ? key_i[s][5]    :
                                 rnd_type[2] ? key_i[s][5]    :
                                 rnd_type[3] ? spec_in_192[s] : key_i[s][3];
              end
              CIPH_INV: begin
                rot_word_in[s] = rnd_type[1] ? key_i[s][3] :
                                 rnd_type[2] ? key_i[s][1] : key_i[s][3];
              end
              default: rot_word_in[s] = key_i[s][3];
            endcase
          end else begin
            rot_word_in[s] = key_i[s][3];
          end
        end

        /////////////
        // AES-256 //
        /////////////
        AES_256: begin
          unique case (op_i)
            CIPH_FWD: rot_word_in[s] = key_i[s][7];
            CIPH_INV: rot_word_in[s] = key_i[s][3];
            default:  rot_word_in[s] = key_i[s][7];
          endcase
        end

        default: rot_word_in[s] = key_i[s][3];
      endcase
    end

    // RotWord: cyclic byte shift
    assign rot_word_out[s] = aes_circ_byte_shift(rot_word_in[s], 2'h3);
  end

  // Mux input for SubWord
  assign sub_word_in = use_rot_word ? rot_word_out[0] : rot_word_in[0];

  // Masking
  if (!SecMasking) begin : gen_no_sw_in_mask
    // The mask share is ignored anyway, it can be 0.
    assign sw_in_mask  = '0;

    // Tie-off unused signals.
    logic [31:0] unused_sw_out_mask;
    assign unused_sw_out_mask = sw_out_mask;

  end else begin : gen_sw_in_mask
    // The input mask is the mask share of rot_word_in/out.
    assign sw_in_mask = use_rot_word ? rot_word_out[1] : rot_word_in[1];
  end

  // SubWord - individually substitute bytes.
  // Every DOM S-Box instance consumes 28 bits of randomness but itself produces 20 bits for use in
  // another S-Box instance. For other S-Box implementations, only the bits corresponding to prd_i
  // are used. Other bits are ignored and tied to 0.
  logic [3:0][WidthPRDSBox+19:0] in_prd;
  logic [3:0]             [19:0] out_prd;

  for (genvar i = 0; i < 4; i++) begin : gen_sbox
    // Rotate the randomness produced by the S-Boxes. The LSBs are taken from the masking PRNG
    // (prd_i) whereas the MSBs are produced by the other S-Box instances.
    assign in_prd[i] = {out_prd[aes_rot_int(i,4)], prd_i[WidthPRDSBox*i +: WidthPRDSBox]};

    aes_sbox #(
      .SecSBoxImpl ( SecSBoxImpl )
    ) u_aes_sbox_i (
      .clk_i     ( clk_i                  ),
      .rst_ni    ( rst_ni                 ),
      .en_i      ( en == SP2V_HIGH        ),
      .out_req_o ( sub_word_out_req[i]    ),
      .out_ack_i ( out_ack == SP2V_HIGH   ),
      .op_i      ( CIPH_FWD               ),
      .data_i    ( sub_word_in[8*i +: 8]  ),
      .mask_i    ( sw_in_mask[8*i +: 8]   ),
      .prd_i     ( in_prd[i]              ),
      .data_o    ( sub_word_out[8*i +: 8] ),
      .mask_o    ( sw_out_mask[8*i +: 8]  ),
      .prd_o     ( out_prd[i]             )
    );
  end

  // Add Rcon
  assign rcon_add_in  = sub_word_out[7:0];
  assign rcon_add_out = rcon_add_in ^ rcon_q;
  assign rcon_added   = {sub_word_out[31:8], rcon_add_out};

  // Mux output coming from Rcon & SubWord
  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_irregular
    if (s == 0) begin : gen_irregular_rcon
      // The (masked) key share
      assign irregular[s] = use_rcon ? rcon_added : sub_word_out;
    end else begin : gen_irregular_no_rcon
      // The mask share
      assign irregular[s] = sw_out_mask;
    end
  end

  ///////////////////////////
  // The more regular part //
  ///////////////////////////

  // To reduce muxing resources, we re-use existing
  // connections for unused words and default cases.
  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_regular
    always_comb begin : drive_regular
      unique case (key_len_i)

        /////////////
        // AES-128 //
        /////////////
        AES_128: begin
          // key_o[7:4] not used
          regular[s][7:4] = key_i[s][3:0];

          regular[s][0] = irregular[s] ^ key_i[s][0];
          unique case (op_i)
            CIPH_FWD: begin
              for (int i = 1; i < 4; i++) begin
                regular[s][i] = regular[s][i-1] ^ key_i[s][i];
              end
            end

            CIPH_INV: begin
              for (int i = 1; i < 4; i++) begin
                regular[s][i] = key_i[s][i-1] ^ key_i[s][i];
              end
            end

            default: regular[s] = {key_i[s][3:0], key_i[s][7:4]};
          endcase
        end

        /////////////
        // AES-192 //
        /////////////
        AES_192: begin
          // key_o[7:6] not used
          regular[s][7:6] = key_i[s][3:2];

          if (AES192Enable) begin
            unique case (op_i)
              CIPH_FWD: begin
                if (rnd_type[0]) begin
                  // Shift down four upper most words
                  regular[s][3:0] = key_i[s][5:2];
                  // Generate Words 6 and 7
                  regular[s][4]   = irregular[s]  ^ key_i[s][0];
                  regular[s][5]   = regular[s][4] ^ key_i[s][1];
                end else begin
                  // Shift down two upper most words
                  regular[s][1:0] = key_i[s][5:4];
                  // Generate new upper four words
                  for (int i = 0; i < 4; i++) begin
                    if ((i == 0 && rnd_type[2]) ||
                        (i == 2 && rnd_type[3])) begin
                      regular[s][i+2] = irregular[s]    ^ key_i[s][i];
                    end else begin
                      regular[s][i+2] = regular[s][i+1] ^ key_i[s][i];
                    end
                  end
                end // rnd_type[0]
              end

              CIPH_INV: begin
                if (rnd_type[0]) begin
                  // Shift up four lowest words
                  regular[s][5:2] = key_i[s][3:0];
                  // Generate Word 44 and 45
                  for (int i = 0; i < 2; i++) begin
                    regular[s][i] = key_i[s][3+i] ^ key_i[s][3+i+1];
                  end
                end else begin
                  // Shift up two lowest words
                  regular[s][5:4] = key_i[s][1:0];
                  // Generate new lower four words
                  for (int i = 0; i < 4; i++) begin
                    if ((i == 2 && rnd_type[1]) ||
                        (i == 0 && rnd_type[2])) begin
                      regular[s][i] = irregular[s]  ^ key_i[s][i+2];
                    end else begin
                      regular[s][i] = key_i[s][i+1] ^ key_i[s][i+2];
                    end
                  end
                end // rnd_type[0]
              end

              default: regular[s] = {key_i[s][3:0], key_i[s][7:4]};
            endcase

          end else begin
            regular[s] = {key_i[s][3:0], key_i[s][7:4]};
          end // AES192Enable
        end

        /////////////
        // AES-256 //
        /////////////
        AES_256: begin
          unique case (op_i)
            CIPH_FWD: begin
              if (rnd == 0) begin
                // Round 0: Nothing to be done
                // The Full Key registers are not updated
                regular[s] = {key_i[s][3:0], key_i[s][7:4]};
              end else begin
                // Shift down old upper half
                regular[s][3:0] = key_i[s][7:4];
                // Generate new upper half
                regular[s][4]   = irregular[s] ^ key_i[s][0];
                for (int i = 1; i < 4; i++) begin
                  regular[s][i+4] = regular[s][i+4-1] ^ key_i[s][i];
                end
              end // rnd == 0
            end

            CIPH_INV: begin
              if (rnd == 0) begin
                // Round 0: Nothing to be done
                // The Full Key registers are not updated
                regular[s] = {key_i[s][3:0], key_i[s][7:4]};
              end else begin
                // Shift up old lower half
                regular[s][7:4] = key_i[s][3:0];
                // Generate new lower half
                regular[s][0]   = irregular[s] ^ key_i[s][4];
                for (int i = 0; i < 3; i++) begin
                  regular[s][i+1] = key_i[s][4+i] ^ key_i[s][4+i+1];
                end
              end // rnd == 0
            end

            default: regular[s] = {key_i[s][3:0], key_i[s][7:4]};
          endcase
        end

        default: regular[s] = {key_i[s][3:0], key_i[s][7:4]};
      endcase // key_len_i
    end // drive_regular
  end // gen_shares_regular

  // Drive output
  assign key_o     = regular;
  assign out_req_o = &sub_word_out_req ? SP2V_HIGH : SP2V_LOW;

  //////////////////////////////
  // Sparsely Encoded Signals //
  //////////////////////////////

  logic [Sp2VWidth-1:0] en_raw;
  aes_sel_buf_chk #(
    .Num      ( Sp2VNum   ),
    .Width    ( Sp2VWidth ),
    .EnSecBuf ( 1'b1      )
  ) u_aes_key_expand_en_buf_chk (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),
    .sel_i  ( en_i   ),
    .sel_o  ( en_raw ),
    .err_o  ( en_err )
  );
  assign en = sp2v_e'(en_raw);

  logic [Sp2VWidth-1:0] out_ack_raw;
  aes_sel_buf_chk #(
    .Num      ( Sp2VNum   ),
    .Width    ( Sp2VWidth ),
    .EnSecBuf ( 1'b1      )
  ) u_aes_key_expand_out_ack_buf_chk (
    .clk_i  ( clk_i       ),
    .rst_ni ( rst_ni      ),
    .sel_i  ( out_ack_i   ),
    .sel_o  ( out_ack_raw ),
    .err_o  ( out_ack_err )
  );
  assign out_ack = sp2v_e'(out_ack_raw);

  // Collect encoding errors.
  assign err_o = en_err | out_ack_err;

  ////////////////
  // Assertions //
  ////////////////

  // Create a lint error to reduce the risk of accidentally disabling the masking.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesKeyExpandSecMaskingNonDefault, SecMasking == 1)

  // Cipher core masking requires a masked SBox and vice versa.
  `CALIPTRA_ASSERT_INIT(AesMaskedCoreAndSBox,
      (SecMasking &&
      (SecSBoxImpl == SBoxImplCanrightMasked ||
       SecSBoxImpl == SBoxImplCanrightMaskedNoreuse ||
       SecSBoxImpl == SBoxImplDom)) ||
      (!SecMasking &&
      (SecSBoxImpl == SBoxImplLut ||
       SecSBoxImpl == SBoxImplCanright)))

  // Selectors must be known/valid
  `CALIPTRA_ASSERT(AesCiphOpValid, cfg_valid_i |-> op_i inside {
      CIPH_FWD,
      CIPH_INV
      })
  `CALIPTRA_ASSERT(AesKeyLenValid, cfg_valid_i |-> key_len_i inside {
      AES_128,
      AES_192,
      AES_256
      })

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES MixColumns

module aes_mix_columns (
  input  aes_pkg::ciph_op_e    op_i,
  input  logic [3:0][3:0][7:0] data_i,
  output logic [3:0][3:0][7:0] data_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;

  // Transpose to operate on columns
  logic [3:0][3:0][7:0] data_i_transposed;
  logic [3:0][3:0][7:0] data_o_transposed;

  assign data_i_transposed = aes_transpose(data_i);

  // Individually mix columns
  for (genvar i = 0; i < 4; i++) begin : gen_mix_column
    aes_mix_single_column u_aes_mix_column_i (
      .op_i   ( op_i                 ),
      .data_i ( data_i_transposed[i] ),
      .data_o ( data_o_transposed[i] )
    );
  end

  assign data_o = aes_transpose(data_o_transposed);

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES MixColumns for one single column of the state matrix
//
// For details, see Equations 4-7 of:
// Satoh et al., "A Compact Rijndael Hardware Architecture with S-Box Optimization"

module aes_mix_single_column (
  input  aes_pkg::ciph_op_e op_i,
  input  logic [3:0][7:0]   data_i,
  output logic [3:0][7:0]   data_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;

  logic [3:0][7:0] x;
  logic [1:0][7:0] y;
  logic [1:0][7:0] z;

  logic [3:0][7:0] x_mul2;
  logic [1:0][7:0] y_pre_mul4;
  logic      [7:0] y2, y2_pre_mul2;

  logic [1:0][7:0] z_muxed;

  // Drive x
  assign x[0] = data_i[0] ^ data_i[3];
  assign x[1] = data_i[3] ^ data_i[2];
  assign x[2] = data_i[2] ^ data_i[1];
  assign x[3] = data_i[1] ^ data_i[0];

  // Mul2(x)
  for (genvar i = 0; i < 4; i++) begin : gen_x_mul2
    assign x_mul2[i] = aes_mul2(x[i]);
  end

  // Drive y_pre_mul4
  assign y_pre_mul4[0] = data_i[3] ^ data_i[1];
  assign y_pre_mul4[1] = data_i[2] ^ data_i[0];

  // Mul4(y_pre_mul4)
  for (genvar i = 0; i < 2; i++) begin : gen_mul4
    assign y[i] = aes_mul4(y_pre_mul4[i]);
  end

  // Drive y2_pre_mul2
  assign y2_pre_mul2 = y[0] ^ y[1];

  // Mul2(y)
  assign y2 = aes_mul2(y2_pre_mul2);

  // Drive z
  assign z[0] = y2 ^ y[0];
  assign z[1] = y2 ^ y[1];

  // Mux z
  assign z_muxed[0] = (op_i == CIPH_FWD) ? 8'b0 :
                      (op_i == CIPH_INV) ? z[0] : 8'b0;
  assign z_muxed[1] = (op_i == CIPH_FWD) ? 8'b0 :
                      (op_i == CIPH_INV) ? z[1] : 8'b0;

  // Drive outputs
  assign data_o[0] = data_i[1] ^ x_mul2[3] ^ x[1] ^ z_muxed[1];
  assign data_o[1] = data_i[0] ^ x_mul2[2] ^ x[1] ^ z_muxed[0];
  assign data_o[2] = data_i[3] ^ x_mul2[1] ^ x[3] ^ z_muxed[1];
  assign data_o[3] = data_i[2] ^ x_mul2[0] ^ x[3] ^ z_muxed[0];

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES high-bandwidth pseudo-random number generator for masking
//
// This module uses multiple parallel LFSRs each one of them followed by an aligned permutation, a
// non-linear layer (PRINCE S-Boxes) and another permutation layer spanning across all LFSRs to
// generate pseudo-random data for masking the AES cipher core. The LFSRs can be reseeded using an
// external interface.

///////////////////////////////////////////////////////////////////////////////////////////////////
// IMPORTANT NOTE:                                                                               //
//                                   DO NOT USE THIS BLINDLY!                                    //
//                                                                                               //
// It has not yet been verified that this initial implementation produces pseudo-random numbers  //
// of sufficient quality in terms of uniformity and independence, and that it is indeed suitable //
// for masking purposes.                                                                         //
///////////////////////////////////////////////////////////////////////////////////////////////////

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_prng_masking 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter  int unsigned Width        = WidthPRDMasking,     // Must be divisble by ChunkSize and 8
  parameter  int unsigned ChunkSize    = ChunkSizePRDMasking, // Width of the LFSR primitives
  parameter  int unsigned EntropyWidth = edn_pkg::ENDPOINT_BUS_WIDTH,
  parameter  bit          SecAllowForcingMasks  = 0, // Allow forcing masks to constant values using
                                                     // force_masks_i. Useful for SCA only.
  parameter  bit          SecSkipPRNGReseeding  = 0, // The current SCA setup doesn't provide
                                                     // sufficient resources to implement the
                                                     // infrastructure required for PRNG reseeding.
                                                     // To enable SCA resistance evaluations, we
                                                     // need to skip reseeding requests.

  localparam int unsigned NumChunks = Width/ChunkSize, // derived parameter

  parameter masking_lfsr_seed_t RndCnstLfsrSeed = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t RndCnstLfsrPerm = RndCnstMaskingLfsrPermDefault
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  input  logic                    force_masks_i,

  // Connections to AES internals, PRNG consumers
  input  logic                    data_update_i,
  output logic        [Width-1:0] data_o,
  input  logic                    reseed_req_i,
  output logic                    reseed_ack_o,

  // Connections to outer world, LFSR reseeding
  output logic                    entropy_req_o,
  input  logic                    entropy_ack_i,
  input  logic [EntropyWidth-1:0] entropy_i
);

  logic                [NumChunks-1:0] prng_seed_en;
  logic [NumChunks-1:0][ChunkSize-1:0] prng_seed;
  logic                                prng_en;
  logic [NumChunks-1:0][ChunkSize-1:0] prng_state, perm;
  logic                    [Width-1:0] prng_b, perm_b;
  logic                                phase_q;

  /////////////
  // Control //
  /////////////

  // The data requests are fed from the LFSRs. Reseed requests take precedence internally to the
  // LFSRs. If there is an outstanding reseed request, the PRNG can keep updating and providing
  // pseudo-random data (using the old seed). If the reseeding is taking place, the LFSRs will
  // provide fresh pseudo-random data (the new seed) in the next cycle anyway. This means the
  // PRNG is always ready to provide new pseudo-random data.

  // In the current SCA setup, we don't have sufficient resources to implement the infrastructure
  // required for PRNG reseeding (CSRNG, EDN, etc.). Therefore, we skip any reseeding requests if
  // the SecSkipPRNGReseeding parameter is set. Performing the reseeding without proper entropy
  // provided from CSRNG would result in quickly repeating, fully deterministic PRNG output,
  // which prevents meaningful SCA resistance evaluations.

  // Create a lint error to reduce the risk of accidentally enabling this feature.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesSecAllowForcingMasksNonDefault, SecAllowForcingMasks == 0)

  if (SecAllowForcingMasks == 0) begin : gen_unused_force_masks
    logic unused_force_masks;
    assign unused_force_masks = force_masks_i;
  end

  // PRNG control
  assign prng_en = (SecAllowForcingMasks && force_masks_i) ? 1'b0 : data_update_i;

  // Create a lint error to reduce the risk of accidentally enabling this feature.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesSecSkipPRNGReseedingNonDefault, SecSkipPRNGReseeding == 0)

  // Width adaption for reseeding interface. We get EntropyWidth bits at a time.
  if (ChunkSize == EntropyWidth) begin : gen_counter
    // We can reseed chunk by chunk as we get fresh entropy. Need to keep track of which chunk to
    // reseed next.
    localparam int unsigned ChunkIdxWidth = caliptra_prim_util_pkg::vbits(NumChunks);
    logic [ChunkIdxWidth-1:0] chunk_idx_d, chunk_idx_q;
    logic                     prng_reseed_done;

    // Stop requesting entropy once every chunk got reseeded.
    assign entropy_req_o = SecSkipPRNGReseeding ? 1'b0         : reseed_req_i;
    assign reseed_ack_o  = SecSkipPRNGReseeding ? reseed_req_i : prng_reseed_done;

    // Counter
    assign prng_reseed_done =
        (chunk_idx_q == ChunkIdxWidth'(NumChunks - 1)) & entropy_req_o & entropy_ack_i;
    assign chunk_idx_d = prng_reseed_done ? '0                              :
        entropy_req_o && entropy_ack_i    ? chunk_idx_q + ChunkIdxWidth'(1) : chunk_idx_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin : reg_chunk_idx
      if (!rst_ni) begin
        chunk_idx_q <= '0;
      end else begin
        chunk_idx_q <= chunk_idx_d;
      end
    end

    // The entropy input is forwarded to all chunks, we just control the seed enable.
    for (genvar c = 0; c < NumChunks; c++) begin : gen_seeds
      assign prng_seed[c]    = entropy_i;
      assign prng_seed_en[c] = (c == chunk_idx_q) ? entropy_req_o & entropy_ack_i : 1'b0;
    end

  end else begin : gen_packer
    // Upsizing of entropy input to correct width for reseeding the full PRNG in one shot.
    logic [Width-1:0] seed;
    logic             seed_valid;

    // Stop requesting entropy once the desired amount is available.
    assign entropy_req_o = SecSkipPRNGReseeding ? 1'b0         : reseed_req_i & ~seed_valid;
    assign reseed_ack_o  = SecSkipPRNGReseeding ? reseed_req_i : seed_valid;

    caliptra_prim_packer_fifo #(
      .InW         ( EntropyWidth ),
      .OutW        ( Width        ),
      .ClearOnRead ( 1'b0         )
    ) u_caliptra_prim_packer_fifo (
      .clk_i    ( clk_i         ),
      .rst_ni   ( rst_ni        ),
      .clr_i    ( 1'b0          ), // Not needed.
      .wvalid_i ( entropy_ack_i ),
      .wdata_i  ( entropy_i     ),
      .wready_o (               ), // Not needed, we're always ready to sink data at this point.
      .rvalid_o ( seed_valid    ),
      .rdata_o  ( seed          ),
      .rready_i ( 1'b1          ), // We're always ready to receive the packed output word.
      .depth_o  (               )  // Not needed.
    );

    // Extract chunk seeds. All chunks get reseeded together.
    for (genvar c = 0; c < NumChunks; c++) begin : gen_seeds
      assign prng_seed[c]    = seed[c * ChunkSize +: ChunkSize];
      assign prng_seed_en[c] = SecSkipPRNGReseeding ? 1'b0 : seed_valid;
    end
  end

  ///////////
  // LFSRs //
  ///////////

  // We use multiple LFSR instances each having a width of ChunkSize.
  for (genvar c = 0; c < NumChunks; c++) begin : gen_lfsrs
    caliptra_prim_lfsr #(
      .LfsrType     ( "GAL_XOR"                                   ),
      .LfsrDw       ( ChunkSize                                   ),
      .StateOutDw   ( ChunkSize                                   ),
      .DefaultSeed  ( RndCnstLfsrSeed[c * ChunkSize +: ChunkSize] ),
      .StatePermEn  ( 1'b0                                        ),
      .NonLinearOut ( 1'b1                                        )
    ) u_lfsr_chunk (
      .clk_i     ( clk_i           ),
      .rst_ni    ( rst_ni          ),
      .seed_en_i ( prng_seed_en[c] ),
      .seed_i    ( prng_seed[c]    ),
      .lfsr_en_i ( prng_en         ),
      .entropy_i ( '0              ),
      .state_o   ( prng_state[c]   )
    );
  end

  // Add a permutation layer spanning across all LFSRs to break linear shift patterns.
  assign prng_b = prng_state;
  for (genvar b = 0; b < Width; b++) begin : gen_perm
    assign perm_b[b] = prng_b[RndCnstLfsrPerm[b]];
  end
  assign perm = perm_b;

  /////////////
  // Outputs //
  /////////////

  // To achieve independence of input and output masks (the output mask of round X is the input
  // mask of round X+1), we assign the scrambled chunks to the output data in alternating fashion.
  assign data_o = phase_q ? {perm[0], perm[NumChunks-1:1]} : perm;

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_phase
    if (!rst_ni) begin
      phase_q <= '0;
    end else if (prng_en) begin
      phase_q <= ~phase_q;
    end
  end

  /////////////////
  // Asssertions //
  /////////////////

  // Width must be divisible by ChunkSize
  `CALIPTRA_ASSERT_INIT(AesPrngMaskingWidthByChunk, Width % ChunkSize == 0)
  // Width must be divisible by 8
  `CALIPTRA_ASSERT_INIT(AesPrngMaskingWidthBy8, Width % 8 == 0)

// the code below is not meant to be synthesized,
// but it is intended to be used in simulation and FPV
`ifndef SYNTHESIS
  // Check that the supplied permutation is valid.
  logic [Width-1:0] perm_test;
  initial begin : p_perm_check
    perm_test = '0;
    for (int k = 0; k < Width; k++) begin
      perm_test[RndCnstLfsrPerm[k]] = 1'b1;
    end
    // All bit positions must be marked with 1.
    `CALIPTRA_ASSERT_I(PermutationCheck_A, &perm_test)
  end
`endif

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES Masked Canright SBox without Mask Re-Use
//
// For details, see the following paper:
// Canright, "A very compact 'perfectly masked' S-box for AES (corrected)"
// available at https://eprint.iacr.org/2009/011.pdf
//
// Note: This module implements the original masked inversion algorithm without re-using masks.
// For details, see Section 2.2 of the paper. In addition, a formal analysis using REBECCA (stable
// mode) shows that the intermediate masks cannot be created by re-using bits from the input and
// output masks. Instead, fresh random bits need to be used for these intermediate masks. Still,
// the implmentation cannot be made to pass formal analysis in transient mode. It's usage is thus
// discouraged. It's included here mainly for reference.
//
// For details on the REBECCA tool, see the following paper:
// Bloem, "Formal verification of masked hardware implementations in the presence of glitches"
// available at https://eprint.iacr.org/2017/897.pdf

///////////////////////////////////////////////////////////////////////////////////////////////////
// IMPORTANT NOTE:                                                                               //
//                            DO NOT USE THIS FOR SYNTHESIS BLINDLY!                             //
//                                                                                               //
// This implementation relies on primitive cells like caliptra_prim_buf containing tool-specific          //
// synthesis attributes to enforce the correct ordering of operations and avoid aggressive       //
// optimization. Without the proper primitives, synthesis tools might heavily optimize the       //
// design. The result is likely insecure. Use with care.                                         //
///////////////////////////////////////////////////////////////////////////////////////////////////

// Masked inverse in GF(2^4), using normal basis [z^4, z]
// (see Formulas 6, 13, 14, 15, 16, 17 in the paper)
module aes_masked_inverse_gf2p4_noreuse (
  input  logic [3:0] b,
  input  logic [3:0] q,
  input  logic [1:0] r,
  input  logic [3:0] t,
  output logic [3:0] b_inv
);

  import aes_reg_pkg::*;
  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  logic [1:0] b1, b0, q1, q0, c_inv, r_sq, t1, t0;
  assign b1 = b[3:2];
  assign b0 = b[1:0];
  assign q1 = q[3:2];
  assign q0 = q[1:0];
  assign t1 = t[3:2];
  assign t0 = t[1:0];

  ////////////////
  // Formula 13 //
  ////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // c = r ^ aes_scale_omega2_gf2p2(aes_square_gf2p2(b1 ^ b0))
  //       ^ aes_scale_omega2_gf2p2(aes_square_gf2p2(q1 ^ q0))
  //       ^ aes_mul_gf2p2(b1, b0)
  //       ^ aes_mul_gf2p2(b1, q0) ^ aes_mul_gf2p2(b0, q1) ^ aes_mul_gf2p2(q1, q0);

  // Get intermediate terms.
  logic [1:0] scale_omega2_b, scale_omega2_q;
  logic [1:0] mul_b1_b0, mul_b1_q0, mul_b0_q1, mul_q1_q0;
  assign scale_omega2_b = aes_scale_omega2_gf2p2(aes_square_gf2p2(b1 ^ b0));
  assign scale_omega2_q = aes_scale_omega2_gf2p2(aes_square_gf2p2(q1 ^ q0));
  assign mul_b1_b0 = aes_mul_gf2p2(b1, b0);
  assign mul_b1_q0 = aes_mul_gf2p2(b1, q0);
  assign mul_b0_q1 = aes_mul_gf2p2(b0, q1);
  assign mul_q1_q0 = aes_mul_gf2p2(q1, q0);

  // These terms are added to other terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [1:0] scale_omega2_b_buf, scale_omega2_q_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_scale_omega2_bq (
    .in_i  ( {scale_omega2_b,     scale_omega2_q}     ),
    .out_o ( {scale_omega2_b_buf, scale_omega2_q_buf} )
  );
  logic [1:0] mul_b1_b0_buf, mul_b1_q0_buf, mul_b0_q1_buf, mul_q1_q0_buf;
  caliptra_prim_buf #(
    .Width ( 8 )
  ) u_caliptra_prim_buf_mul_bq01 (
    .in_i  ( {mul_b1_b0,     mul_b1_q0,     mul_b0_q1,     mul_q1_q0}     ),
    .out_o ( {mul_b1_b0_buf, mul_b1_q0_buf, mul_b0_q1_buf, mul_q1_q0_buf} )
  );

  // Generate c step by step.
  logic [1:0] c [6];
  logic [1:0] c_buf [6];
  assign c[0] = r        ^ scale_omega2_b_buf;
  assign c[1] = c_buf[0] ^ scale_omega2_q_buf;
  assign c[2] = c_buf[1] ^ mul_b1_b0_buf;
  assign c[3] = c_buf[2] ^ mul_b1_q0_buf;
  assign c[4] = c_buf[3] ^ mul_b0_q1_buf;
  assign c[5] = c_buf[4] ^ mul_q1_q0_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 6; i++) begin : gen_c_buf
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_c_i (
      .in_i  ( c[i]     ),
      .out_o ( c_buf[i] )
    );
  end

  ////////////////////////
  // Formulas 14 and 15 //
  ////////////////////////
  // Note: aes_square_gf2p2 contains no logic, it's just a bit swap. There is no need to insert
  // additional buffers to stop aggressive synthesis optimizations here.
  assign c_inv = aes_square_gf2p2(c_buf[5]);
  assign r_sq  = aes_square_gf2p2(r);

  ////////////////////////
  // Formulas 16 and 17 //
  ////////////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // b1_inv = t1 ^ aes_mul_gf2p2(b0, c_inv)
  //             ^ aes_mul_gf2p2(b0, r_sq) ^ aes_mul_gf2p2(q0, c_inv) ^ aes_mul_gf2p2(q0, r_sq);
  // b0_inv = t0 ^ aes_mul_gf2p2(b1, c_inv)
  //             ^ aes_mul_gf2p2(b1, r_sq) ^ aes_mul_gf2p2(q1, c_inv) ^ aes_mul_gf2p2(q1, r_sq);

  // Get intermediate terms.
  logic [1:0] mul_b0_r_sq, mul_q0_c_inv, mul_q0_r_sq;
  logic [1:0] mul_b1_r_sq, mul_q1_c_inv, mul_q1_r_sq;
  assign mul_b0_r_sq  = aes_mul_gf2p2(b0, r_sq);
  assign mul_q0_c_inv = aes_mul_gf2p2(q0, c_inv);
  assign mul_q0_r_sq  = aes_mul_gf2p2(q0, r_sq);
  assign mul_b1_r_sq  = aes_mul_gf2p2(b1, r_sq);
  assign mul_q1_c_inv = aes_mul_gf2p2(q1, c_inv);
  assign mul_q1_r_sq  = aes_mul_gf2p2(q1, r_sq);

  // The multiplier outputs are added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [1:0] mul_b0_r_sq_buf, mul_q0_c_inv_buf, mul_q0_r_sq_buf;
  caliptra_prim_buf #(
    .Width ( 6 )
  ) u_caliptra_prim_buf_mul_bq0 (
    .in_i  ( {mul_b0_r_sq,     mul_q0_c_inv,     mul_q0_r_sq}     ),
    .out_o ( {mul_b0_r_sq_buf, mul_q0_c_inv_buf, mul_q0_r_sq_buf} )
  );
  logic [1:0] mul_b1_r_sq_buf, mul_q1_c_inv_buf, mul_q1_r_sq_buf;
  caliptra_prim_buf #(
    .Width ( 6 )
  ) u_caliptra_prim_buf_mul_bq1 (
    .in_i  ( {mul_b1_r_sq,     mul_q1_c_inv,     mul_q1_r_sq}     ),
    .out_o ( {mul_b1_r_sq_buf, mul_q1_c_inv_buf, mul_q1_r_sq_buf} )
  );

  // Generate b1_inv and b0_inv step by step.
  logic [1:0] b1_inv [4];
  logic [1:0] b1_inv_buf [4];
  logic [1:0] b0_inv [4];
  logic [1:0] b0_inv_buf [4];
  assign b1_inv[0] = t1            ^ aes_mul_gf2p2(b0, c_inv); // t1 does not depend on b0, c_inv.
  assign b1_inv[1] = b1_inv_buf[0] ^ mul_b0_r_sq_buf;
  assign b1_inv[2] = b1_inv_buf[1] ^ mul_q0_c_inv_buf;
  assign b1_inv[3] = b1_inv_buf[2] ^ mul_q0_r_sq_buf;
  assign b0_inv[0] = t0            ^ aes_mul_gf2p2(b1, c_inv); // t0 does not depend on b1, c_inv.
  assign b0_inv[1] = b0_inv_buf[0] ^ mul_b1_r_sq_buf;
  assign b0_inv[2] = b0_inv_buf[1] ^ mul_q1_c_inv_buf;
  assign b0_inv[3] = b0_inv_buf[2] ^ mul_q1_r_sq_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 4; i++) begin : gen_a01_inv_buf
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_b1_inv_i (
      .in_i  ( b1_inv[i]     ),
      .out_o ( b1_inv_buf[i] )
    );
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_b0_inv_i (
      .in_i  ( b0_inv[i]     ),
      .out_o ( b0_inv_buf[i] )
    );
  end

  // Note: b_inv is masked by t, b was masked by q.
  assign b_inv = {b1_inv_buf[3], b0_inv_buf[3]};

endmodule

// Masked inverse in GF(2^8), using normal basis [y^16, y]
// (see Formulas 3, 12, 18 and 19 in the paper)
module aes_masked_inverse_gf2p8_noreuse (
  input  logic [7:0] a,    // input data masked by m
  input  logic [7:0] m,    // input mask
  input  logic [7:0] n,    // output mask
  input  logic [9:0] prd,  // pseudo-random data, e.g. for intermediate masks
  output logic [7:0] a_inv // output data masked by n
);

  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  logic [3:0] a1, a0, m1, m0, q, b_inv, s1, s0, t;
  logic [1:0] r;

  assign a1 = a[7:4];
  assign a0 = a[3:0];
  assign m1 = m[7:4];
  assign m0 = m[3:0];

  ////////////////////
  // Notes on masks //
  ////////////////////
  // The paper states the following.
  // r:
  // - must be independent of q,
  // - it is suggested to re-use bits of m,
  // - but further analysis shows that this is not sufficient (see below).
  //
  // q:
  // - must be independent of m.
  //
  // t:
  // - must be independent of r,
  // - must be independent of m (for the final steps involving s),
  // - t1 must be independent of q0, t0 must be independent of q1,
  // - it is suggested to use t = q,
  // - but further analysis shows that this is not sufficient (see below).
  //
  // s:
  // - must be independent of t,
  // - s1 must be independent of m0, s0 must be independent of m1,
  // - it is suggested to use s = m,
  // - but further analysis shows that this is not sufficient (see below).
  //
  // Formally analyzing the implementation with REBECCA reveals that:
  // 1. Fresh random bits are required for r, q and t. Any re-use of other mask bits from m or n
  //    causes the static check to fail.
  // 2. s can be the specified output mask n.
  assign r  = prd[1:0];
  assign q  = prd[5:2];
  assign t  = prd[9:6];
  assign s1 = n[7:4];
  assign s0 = n[3:0];

  ////////////////
  // Formula 12 //
  ////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // b = q ^ aes_square_scale_gf2p4_gf2p2(a1 ^ a0)
  //       ^ aes_square_scale_gf2p4_gf2p2(m1 ^ m0)
  //       ^ aes_mul_gf2p4(a1, a0)
  //       ^ aes_mul_gf2p4(a1, m0) ^ aes_mul_gf2p4(a0, m1) ^ aes_mul_gf2p4(m0, m1);

  // Get intermediate terms.
  logic [3:0] ss_a1_a0, ss_m1_m0;
  assign ss_a1_a0 = aes_square_scale_gf2p4_gf2p2(a1 ^ a0);
  assign ss_m1_m0 = aes_square_scale_gf2p4_gf2p2(m1 ^ m0);

  logic [3:0] mul_a1_a0, mul_a1_m0, mul_a0_m1, mul_m0_m1;
  assign mul_a1_a0 = aes_mul_gf2p4(a1, a0);
  assign mul_a1_m0 = aes_mul_gf2p4(a1, m0);
  assign mul_a0_m1 = aes_mul_gf2p4(a0, m1);
  assign mul_m0_m1 = aes_mul_gf2p4(m0, m1);

  // The multiplier outputs are added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [3:0] mul_a1_a0_buf, mul_a1_m0_buf, mul_a0_m1_buf, mul_m0_m1_buf;
  caliptra_prim_buf #(
    .Width ( 16 )
  ) u_caliptra_prim_buf_mul_am01 (
    .in_i  ( {mul_a1_a0,     mul_a1_m0,     mul_a0_m1,     mul_m0_m1}     ),
    .out_o ( {mul_a1_a0_buf, mul_a1_m0_buf, mul_a0_m1_buf, mul_m0_m1_buf} )
  );

  // Generate b step by step.
  logic [3:0] b [6];
  logic [3:0] b_buf [6];
  assign b[0] = q        ^ ss_a1_a0; // q does not depend on a1, a0.
  assign b[1] = b_buf[0] ^ ss_m1_m0; // b[0] does not depend on m1, m0.
  assign b[2] = b_buf[1] ^ mul_a1_a0_buf;
  assign b[3] = b_buf[2] ^ mul_a1_m0_buf;
  assign b[4] = b_buf[3] ^ mul_a0_m1_buf;
  assign b[5] = b_buf[4] ^ mul_m0_m1_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 6; i++) begin : gen_b_buf
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_b_i (
      .in_i  ( b[i]     ),
      .out_o ( b_buf[i] )
    );
  end

  //////////////////////
  // GF(2^4) Inverter //
  //////////////////////

  // b is masked by q, b_inv is masked by t.
  aes_masked_inverse_gf2p4_noreuse u_aes_masked_inverse_gf2p4 (
    .b     ( b_buf[5] ),
    .q     ( q        ),
    .r     ( r        ),
    .t     ( t        ),
    .b_inv ( b_inv    )
  );

  // The output of the inverse over GF(2^4) and signals derived from that are again recombined
  // with inputs to the GF(2^4) inverter. Aggressive synthesis optimizations across the GF(2^4)
  // inverter may result in SCA leakage and should be avoided.
  logic [3:0] b_inv_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_b_inv (
    .in_i  ( b_inv     ),
    .out_o ( b_inv_buf )
  );

  ////////////////////////
  // Formulas 18 and 19 //
  ////////////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // a1_inv = s1 ^ aes_mul_gf2p4(a0, b_inv)
  //             ^ aes_mul_gf2p4(a0, t) ^ aes_mul_gf2p4(m0, b_inv) ^ aes_mul_gf2p4(m0, t);
  // a0_inv = s0 ^ aes_mul_gf2p4(a1, b_inv)
  //             ^ aes_mul_gf2p4(a1, t) ^ aes_mul_gf2p4(m1, b_inv) ^ aes_mul_gf2p4(m1, t);

  // Get intermediate terms.
  logic [3:0] mul_a0_b_inv, mul_a0_t, mul_m0_b_inv, mul_m0_t;
  logic [3:0] mul_a1_b_inv, mul_a1_t, mul_m1_b_inv, mul_m1_t;
  assign mul_a0_b_inv = aes_mul_gf2p4(a0, b_inv_buf);
  assign mul_a0_t     = aes_mul_gf2p4(a0, t);
  assign mul_m0_b_inv = aes_mul_gf2p4(m0, b_inv_buf);
  assign mul_m0_t     = aes_mul_gf2p4(m0, t);
  assign mul_a1_b_inv = aes_mul_gf2p4(a1, b_inv_buf);
  assign mul_a1_t     = aes_mul_gf2p4(a1, t);
  assign mul_m1_b_inv = aes_mul_gf2p4(m1, b_inv_buf);
  assign mul_m1_t     = aes_mul_gf2p4(m1, t);

  // The multiplier outputs are added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [3:0] mul_a0_b_inv_buf, mul_a0_t_buf, mul_m0_b_inv_buf, mul_m0_t_buf;
  caliptra_prim_buf #(
    .Width ( 16 )
  ) u_caliptra_prim_buf_mul_am0 (
    .in_i  ( {mul_a0_b_inv,     mul_a0_t,     mul_m0_b_inv,     mul_m0_t}     ),
    .out_o ( {mul_a0_b_inv_buf, mul_a0_t_buf, mul_m0_b_inv_buf, mul_m0_t_buf} )
  );
  logic [3:0] mul_a1_b_inv_buf, mul_a1_t_buf, mul_m1_b_inv_buf, mul_m1_t_buf;
  caliptra_prim_buf #(
    .Width ( 16 )
  ) u_caliptra_prim_buf_mul_am1 (
    .in_i  ( {mul_a1_b_inv,     mul_a1_t,     mul_m1_b_inv,     mul_m1_t}     ),
    .out_o ( {mul_a1_b_inv_buf, mul_a1_t_buf, mul_m1_b_inv_buf, mul_m1_t_buf} )
  );

  // Generate a1_inv and a0_inv step by step.
  logic [3:0] a1_inv [4];
  logic [3:0] a1_inv_buf [4];
  logic [3:0] a0_inv [4];
  logic [3:0] a0_inv_buf [4];
  assign a1_inv[0] = s1            ^ mul_a0_b_inv_buf;
  assign a1_inv[1] = a1_inv_buf[0] ^ mul_a0_t_buf;
  assign a1_inv[2] = a1_inv_buf[1] ^ mul_m0_b_inv_buf;
  assign a1_inv[3] = a1_inv_buf[2] ^ mul_m0_t_buf;
  assign a0_inv[0] = s0            ^ mul_a1_b_inv_buf;
  assign a0_inv[1] = a0_inv_buf[0] ^ mul_a1_t_buf;
  assign a0_inv[2] = a0_inv_buf[1] ^ mul_m1_b_inv_buf;
  assign a0_inv[3] = a0_inv_buf[2] ^ mul_m1_t_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 4; i++) begin : gen_a01_inv_buf
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_a1_inv_i (
      .in_i  ( a1_inv[i]     ),
      .out_o ( a1_inv_buf[i] )
    );
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_a0_inv_i (
      .in_i  ( a0_inv[i]     ),
      .out_o ( a0_inv_buf[i] )
    );
  end

  // Note: a_inv is masked by s (= n), a was masked by m.
  assign a_inv = {a1_inv_buf[3], a0_inv_buf[3]};

endmodule

// SEC_CM: KEY.MASKING
module aes_sbox_canright_masked_noreuse (
  input  aes_pkg::ciph_op_e op_i,
  input  logic        [7:0] data_i, // masked, the actual input data is data_i ^ mask_i
  input  logic        [7:0] mask_i, // input mask, independent from actual input data
  input  logic       [17:0] prd_i,  // pseudo-random data, for remasking and for intermediate
                                    // masks, must be independent of input mask
  output logic        [7:0] data_o, // masked, the actual output data is data_o ^ mask_o
  output logic        [7:0] mask_o  // output mask
);

  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  //////////////////////////
  // Masked Canright SBox //
  //////////////////////////

  logic [7:0] in_data_basis_x, out_data_basis_x;
  logic [7:0] in_mask_basis_x, out_mask_basis_x;

  // Convert data to normal basis X.
  assign in_data_basis_x = (op_i == CIPH_FWD) ? aes_mvm(data_i, A2X)         :
                           (op_i == CIPH_INV) ? aes_mvm(data_i ^ 8'h63, S2X) :
                                                aes_mvm(data_i, A2X);

  // For the masked Canright SBox with no re-use, the output mask directly corresponds to the
  // LSBs of the pseduo-random data provided as input.
  assign mask_o = prd_i[7:0];

  // The remaining bits are used for intermediate masks.
  logic [9:0] prd_masking;
  assign prd_masking = prd_i[17:8];

  // Convert masks to normal basis X.
  // The addition of constant 8'h63 following the affine transformation is skipped.
  assign in_mask_basis_x  = (op_i == CIPH_FWD) ? aes_mvm(mask_i, A2X) :
                            (op_i == CIPH_INV) ? aes_mvm(mask_i, S2X) :
                                                 aes_mvm(mask_i, A2X);

  // The output mask is converted in the opposite direction.
  assign out_mask_basis_x = (op_i == CIPH_INV) ? aes_mvm(mask_o, A2X) :
                            (op_i == CIPH_FWD) ? aes_mvm(mask_o, S2X) :
                                                 aes_mvm(mask_o, S2X);

  // Do the inversion in normal basis X.
  aes_masked_inverse_gf2p8_noreuse u_aes_masked_inverse_gf2p8 (
    .a     ( in_data_basis_x  ), // input
    .m     ( in_mask_basis_x  ), // input
    .n     ( out_mask_basis_x ), // input
    .prd   ( prd_masking      ), // input
    .a_inv ( out_data_basis_x )  // output
  );

  // Convert to basis S or A.
  assign data_o = (op_i == CIPH_FWD) ? (aes_mvm(out_data_basis_x, X2S) ^ 8'h63) :
                  (op_i == CIPH_INV) ? (aes_mvm(out_data_basis_x, X2A))         :
                                       (aes_mvm(out_data_basis_x, X2S) ^ 8'h63);

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES Masked Canright SBox with Mask Re-Use
//
// For details, see the following paper:
// Canright, "A very compact 'perfectly masked' S-box for AES (corrected)"
// available at https://eprint.iacr.org/2009/011.pdf
//
// Note: This module implements the masked inversion algorithm with re-using masks.
// For details, see Section 2.3 of the paper. Re-using masks may make the implementation more
// vulnerable to higher-order differential side-channel analysis, but it remains secure against
// first-order attacks. This implementation is commonly referred to as THE Canright Masked SBox.
//
// A formal analysis using REBECCA (stable and transient mode) shows that this implementation is
// not secure. It's usage is thus discouraged. It's included here mainly for reference.
//
// For details on the REBECCA tool, see the following paper:
// Bloem, "Formal verification of masked hardware implementations in the presence of glitches"
// available at https://eprint.iacr.org/2017/897.pdf

///////////////////////////////////////////////////////////////////////////////////////////////////
// IMPORTANT NOTE:                                                                               //
//                            DO NOT USE THIS FOR SYNTHESIS BLINDLY!                             //
//                                                                                               //
// This implementation relies on primitive cells like caliptra_prim_buf/xor2 containing tool-specific     //
// synthesis attributes to enforce the correct ordering of operations and avoid aggressive       //
// optimization. Without the proper primitives, synthesis tools might heavily optimize the       //
// design. The result is likely insecure. Use with care.                                         //
///////////////////////////////////////////////////////////////////////////////////////////////////

// Masked inverse in GF(2^4), using normal basis [z^4, z]
// (see Formulas 6, 13, 14, 15, 21, 22, 23, 24 in the paper)
module aes_masked_inverse_gf2p4 (
  input  logic [3:0] b,
  input  logic [3:0] q,
  input  logic [1:0] r,
  input  logic [3:0] m1,
  output logic [3:0] b_inv
);

  import aes_reg_pkg::*;
  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  logic [1:0] b1, b0, q1, q0, c_inv, r_sq, m11, m10;
  assign b1  = b[3:2];
  assign b0  = b[1:0];
  assign q1  = q[3:2];
  assign q0  = q[1:0];
  assign m11 = m1[3:2];
  assign m10 = m1[1:0];

  // Get re-usable intermediate results.
  logic [1:0] mul_b0_q1, mul_b1_q0, mul_q1_q0;
  assign mul_b0_q1 = aes_mul_gf2p2(b0, q1);
  assign mul_b1_q0 = aes_mul_gf2p2(b1, q0);
  assign mul_q1_q0 = aes_mul_gf2p2(q1, q0);

  // Avoid aggressive synthesis optimizations.
  logic [1:0] mul_b0_q1_buf, mul_b1_q0_buf, mul_q1_q0_buf;
  caliptra_prim_buf #(
    .Width ( 6 )
  ) u_caliptra_prim_buf_mul_bq01 (
    .in_i  ( {mul_b0_q1,     mul_b1_q0,     mul_q1_q0}     ),
    .out_o ( {mul_b0_q1_buf, mul_b1_q0_buf, mul_q1_q0_buf} )
  );

  ////////////////
  // Formula 13 //
  ////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // c = r ^ aes_scale_omega2_gf2p2(aes_square_gf2p2(b1 ^ b0))
  //       ^ aes_scale_omega2_gf2p2(aes_square_gf2p2(q1 ^ q0))
  //       ^ aes_mul_gf2p2(b1, b0)
  //       ^ mul_b1_q0 ^ mul_b0_q1 ^ mul_q0_q1;

  // Get intermediate terms.
  logic [1:0] scale_omega2_b, scale_omega2_q;
  logic [1:0] mul_b1_b0;
  assign scale_omega2_b = aes_scale_omega2_gf2p2(aes_square_gf2p2(b1 ^ b0));
  assign scale_omega2_q = aes_scale_omega2_gf2p2(aes_square_gf2p2(q1 ^ q0));
  assign mul_b1_b0 = aes_mul_gf2p2(b1, b0);

  // These terms are added to other terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [1:0] scale_omega2_b_buf, scale_omega2_q_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_scale_omega2_bq (
    .in_i  ( {scale_omega2_b,     scale_omega2_q}     ),
    .out_o ( {scale_omega2_b_buf, scale_omega2_q_buf} )
  );
  logic [1:0] mul_b1_b0_buf;
  caliptra_prim_buf #(
    .Width ( 2 )
  ) u_caliptra_prim_buf_mul_b1_b0 (
    .in_i  ( mul_b1_b0     ),
    .out_o ( mul_b1_b0_buf )
  );

  // Generate c step by step.
  logic [1:0] c [6];
  logic [1:0] c_buf [6];
  assign c[0] = r        ^ scale_omega2_b_buf;
  assign c[1] = c_buf[0] ^ scale_omega2_q_buf;
  assign c[2] = c_buf[1] ^ mul_b1_b0_buf;
  assign c[3] = c_buf[2] ^ mul_b1_q0_buf;
  assign c[4] = c_buf[3] ^ mul_b0_q1_buf;
  assign c[5] = c_buf[4] ^ mul_q1_q0_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 6; i++) begin : gen_c_buf
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_c_i (
      .in_i  ( c[i]     ),
      .out_o ( c_buf[i] )
    );
  end

  ////////////////////////
  // Formulas 14 and 15 //
  ////////////////////////
  // Note: aes_square_gf2p2 contains no logic, it's just a bit swap. There is no need to insert
  // additional buffers to stop aggressive synthesis optimizations here.
  assign c_inv = aes_square_gf2p2(c_buf[5]);
  assign r_sq  = aes_square_gf2p2(r);

  ////////////////////////
  // Formulas 21 and 23 //
  ////////////////////////
  // Re-masking c_inv
  // IMPORTANT: First combine the masks (ops in parens) then apply to c_inv:
  // c_inv  = c_inv ^ (q1 ^ r_sq);
  // c2_inv = c_inv ^ (q0 ^ q1);

  // Get intermediate terms.
  logic [1:0] xor_q1_r_sq, xor_q0_q1, c1_inv, c2_inv;
  caliptra_prim_xor2 #(
    .Width ( 2 )
  ) u_caliptra_prim_xor_q1_r_sq (
    .in0_i ( q1          ),
    .in1_i ( r_sq        ),
    .out_o ( xor_q1_r_sq )
  );
  caliptra_prim_xor2 #(
    .Width ( 2 )
  ) u_caliptra_prim_xor_q0_q1 (
    .in0_i ( q0        ),
    .in1_i ( q1        ),
    .out_o ( xor_q0_q1 )
  );

  // Generate c1_inv and c2_inv.
  caliptra_prim_xor2 #(
    .Width ( 2 )
  ) u_caliptra_prim_c1_inv (
    .in0_i ( xor_q1_r_sq ),
    .in1_i ( c_inv       ),
    .out_o ( c1_inv      )
  );
  caliptra_prim_xor2 #(
    .Width ( 2 )
  ) u_caliptra_prim_c2_inv (
    .in0_i ( c1_inv    ),
    .in1_i ( xor_q0_q1 ),
    .out_o ( c2_inv    )
  );

  ////////////////////////
  // Formulas 22 and 24 //
  ////////////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // b1_inv = m11 ^ aes_mul_gf2p2(b0, c1_inv)
  //              ^ mul_b0_q1 ^ aes_mul_gf2p2(q0, c1_inv) ^ mul_q0_q1;
  // b0_inv = m10 ^ aes_mul_gf2p2(b1, c2_inv)
  //              ^ mul_b1_q0 ^ aes_mul_gf2p2(q1, c2_inv) ^ mul_q0_q1;

  // Get intermediate terms.
  logic [1:0] mul_b0_c1_inv, mul_q0_c1_inv, mul_b1_c2_inv, mul_q1_c2_inv;
  assign mul_b0_c1_inv = aes_mul_gf2p2(b0, c1_inv);
  assign mul_q0_c1_inv = aes_mul_gf2p2(q0, c1_inv);
  assign mul_b1_c2_inv = aes_mul_gf2p2(b1, c2_inv);
  assign mul_q1_c2_inv = aes_mul_gf2p2(q1, c2_inv);

  // The multiplier outputs are added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [1:0] mul_b0_c1_inv_buf, mul_q0_c1_inv_buf, mul_b1_c2_inv_buf, mul_q1_c2_inv_buf;
  caliptra_prim_buf #(
    .Width ( 8 )
  ) u_caliptra_prim_buf_mul_bq01_c12_inv (
    .in_i  ( {mul_b0_c1_inv,     mul_q0_c1_inv,     mul_b1_c2_inv,     mul_q1_c2_inv}     ),
    .out_o ( {mul_b0_c1_inv_buf, mul_q0_c1_inv_buf, mul_b1_c2_inv_buf, mul_q1_c2_inv_buf} )
  );

  // Generate b1_inv and b0_inv step by step.
  logic [1:0] b1_inv [4];
  logic [1:0] b1_inv_buf [4];
  logic [1:0] b0_inv [4];
  logic [1:0] b0_inv_buf [4];
  assign b1_inv[0] = m11           ^ mul_b0_c1_inv_buf;
  assign b1_inv[1] = b1_inv_buf[0] ^ mul_b0_q1_buf;
  assign b1_inv[2] = b1_inv_buf[1] ^ mul_q0_c1_inv_buf;
  assign b1_inv[3] = b1_inv_buf[2] ^ mul_q1_q0_buf;
  assign b0_inv[0] = m10           ^ mul_b1_c2_inv_buf;
  assign b0_inv[1] = b0_inv_buf[0] ^ mul_b1_q0_buf;
  assign b0_inv[2] = b0_inv_buf[1] ^ mul_q1_c2_inv_buf;
  assign b0_inv[3] = b0_inv_buf[2] ^ mul_q1_q0_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 4; i++) begin : gen_a01_inv_buf
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_b1_inv_i (
      .in_i  ( b1_inv[i]     ),
      .out_o ( b1_inv_buf[i] )
    );
    caliptra_prim_buf #(
      .Width ( 2 )
    ) u_caliptra_prim_buf_b0_inv_i (
      .in_i  ( b0_inv[i]     ),
      .out_o ( b0_inv_buf[i] )
    );
  end

  // Note: b_inv is masked by m1, b was masked by q.
  assign b_inv = {b1_inv_buf[3], b0_inv_buf[3]};
endmodule

// Masked inverse in GF(2^8), using normal basis [y^16, y]
// (see Formulas 3, 12, 25, 26 and 27 in the paper)
module aes_masked_inverse_gf2p8 (
  input  logic [7:0] a,
  input  logic [7:0] m,
  input  logic [7:0] n,
  output logic [7:0] a_inv
);

  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  logic [3:0] a1, a0, m1, m0, q, b_inv, s1, s0;
  logic [1:0] r;

  assign a1 = a[7:4];
  assign a0 = a[3:0];
  assign m1 = m[7:4];
  assign m0 = m[3:0];

  ////////////////////
  // Notes on masks //
  ////////////////////
  // The paper states the following.
  // - r must be independent of q.
  // - q must be independent of m.
  // - s is the specified output mask n.
  assign r = m1[3:2];
  assign q = n[7:4];
  assign s1 = n[7:4];
  assign s0 = n[3:0];

  // Get re-usable intermediate results.
  logic [3:0] mul_a0_m1, mul_a1_m0, mul_m0_m1;
  assign mul_a0_m1 = aes_mul_gf2p4(a0, m1);
  assign mul_a1_m0 = aes_mul_gf2p4(a1, m0);
  assign mul_m0_m1 = aes_mul_gf2p4(m0, m1);

  // Avoid aggressive synthesis optimizations.
  logic [3:0] mul_a0_m1_buf, mul_a1_m0_buf, mul_m0_m1_buf;
  caliptra_prim_buf #(
    .Width ( 12 )
  ) u_caliptra_prim_buf_mul_bq01 (
    .in_i  ( {mul_a0_m1,     mul_a1_m0,     mul_m0_m1}     ),
    .out_o ( {mul_a0_m1_buf, mul_a1_m0_buf, mul_m0_m1_buf} )
  );

  ////////////////
  // Formula 12 //
  ////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // b = q ^ aes_square_scale_gf2p4_gf2p2(a1 ^ a0)
  //       ^ aes_square_scale_gf2p4_gf2p2(m1 ^ m0)
  //       ^ aes_mul_gf2p4(a1, a0)
  //       ^ mul_a1_m0 ^ mul_a0_m1 ^ mul_m0_m1;

  // Get intermediate terms.
  logic [3:0] ss_a1_a0, ss_m1_m0;
  assign ss_a1_a0 = aes_square_scale_gf2p4_gf2p2(a1 ^ a0);
  assign ss_m1_m0 = aes_square_scale_gf2p4_gf2p2(m1 ^ m0);

  logic [3:0] mul_a1_a0;
  assign mul_a1_a0 = aes_mul_gf2p4(a1, a0);

  // The multiplier output is added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [3:0] mul_a1_a0_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_mul_am01 (
    .in_i  ( mul_a1_a0     ),
    .out_o ( mul_a1_a0_buf )
  );

  // Generate b step by step.
  logic [3:0] b [6];
  logic [3:0] b_buf [6];
  assign b[0] = q        ^ ss_a1_a0; // q does not depend on a1, a0.
  assign b[1] = b_buf[0] ^ ss_m1_m0; // b[0] does not depend on m1, m0.
  assign b[2] = b_buf[1] ^ mul_a1_a0_buf;
  assign b[3] = b_buf[2] ^ mul_a1_m0_buf;
  assign b[4] = b_buf[3] ^ mul_a0_m1_buf;
  assign b[5] = b_buf[4] ^ mul_m0_m1_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 6; i++) begin : gen_b_buf
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_b_i (
      .in_i  ( b[i]     ),
      .out_o ( b_buf[i] )
    );
  end

  //////////////////////
  // GF(2^4) Inverter //
  //////////////////////

  // b is masked by q, b_inv is masked by m1.
  aes_masked_inverse_gf2p4 u_aes_masked_inverse_gf2p4 (
    .b     ( b_buf[5] ),
    .q     ( q        ),
    .r     ( r        ),
    .m1    ( m1       ),
    .b_inv ( b_inv    )
  );

  // The output of the inverse over GF(2^4) and signals derived from that are again recombined
  // with inputs to the GF(2^4) inverter. Aggressive synthesis optimizations across the GF(2^4)
  // inverter may result in SCA leakage and should be avoided.
  logic [3:0] b_inv_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_b_inv (
    .in_i  ( b_inv     ),
    .out_o ( b_inv_buf )
  );

  ////////////////
  // Formula 26 //
  ////////////////
  // IMPORTANT: First combine the masks (ops in parens) then apply to b_inv:
  // b2_inv = b_inv ^ (m1 ^ m0);

  // Generate b2_inv step by step.
  logic [3:0] xor_m1_m0, b2_inv;
  caliptra_prim_xor2 #(
    .Width ( 4 )
  ) u_caliptra_prim_xor_m1_m0 (
    .in0_i ( m1        ),
    .in1_i ( m0        ),
    .out_o ( xor_m1_m0 )
  );
  caliptra_prim_xor2 #(
    .Width ( 4 )
  ) u_caliptra_prim_xor_b2_inv (
    .in0_i ( b_inv_buf ),
    .in1_i ( xor_m1_m0 ),
    .out_o ( b2_inv    )
  );

  ////////////////////////
  // Formulas 25 and 27 //
  ////////////////////////
  // IMPORTANT: The following ops must be executed in order (left to right):
  // a1_inv = s1 ^ aes_mul_gf2p4(a0, b_inv)
  //             ^ mul_a0_m1 ^ aes_mul_gf2p4(m0, b_inv)  ^ mul_m0_m1;
  // a0_inv = s0 ^ aes_mul_gf2p4(a1, b2_inv)
  //             ^ mul_a1_m0 ^ aes_mul_gf2p4(m1, b2_inv) ^ mul_m0_m1;

  // Get intermediate terms.
  logic [3:0] mul_a0_b_inv, mul_m0_b_inv, mul_a1_b2_inv, mul_m1_b2_inv;
  assign mul_a0_b_inv  = aes_mul_gf2p4(a0, b_inv_buf);
  assign mul_m0_b_inv  = aes_mul_gf2p4(m0, b_inv_buf);
  assign mul_a1_b2_inv = aes_mul_gf2p4(a1, b2_inv);
  assign mul_m1_b2_inv = aes_mul_gf2p4(m1, b2_inv);

  // The multiplier outputs are added to terms that depend on the same inputs.
  // Avoid aggressive synthesis optimizations.
  logic [3:0] mul_a0_b_inv_buf, mul_m0_b_inv_buf, mul_a1_b2_inv_buf, mul_m1_b2_inv_buf;
  caliptra_prim_buf #(
    .Width ( 16 )
  ) u_caliptra_prim_buf_mul_bq01_c12_inv (
    .in_i  ( {mul_a0_b_inv,     mul_m0_b_inv,     mul_a1_b2_inv,     mul_m1_b2_inv}     ),
    .out_o ( {mul_a0_b_inv_buf, mul_m0_b_inv_buf, mul_a1_b2_inv_buf, mul_m1_b2_inv_buf} )
  );

  // Generate a1_inv and a0_inv step by step.
  logic [3:0] a1_inv [4];
  logic [3:0] a1_inv_buf [4];
  logic [3:0] a0_inv [4];
  logic [3:0] a0_inv_buf [4];
  assign a1_inv[0] = s1            ^ mul_a0_b_inv_buf;
  assign a1_inv[1] = a1_inv_buf[0] ^ mul_a0_m1_buf;
  assign a1_inv[2] = a1_inv_buf[1] ^ mul_m0_b_inv_buf;
  assign a1_inv[3] = a1_inv_buf[2] ^ mul_m0_m1_buf;
  assign a0_inv[0] = s0            ^ mul_a1_b2_inv_buf; // s0 doesn't depend on a1, b2_inv.
  assign a0_inv[1] = a0_inv_buf[0] ^ mul_a1_m0_buf;
  assign a0_inv[2] = a0_inv_buf[1] ^ mul_m1_b2_inv_buf;
  assign a0_inv[3] = a0_inv_buf[2] ^ mul_m0_m1_buf;

  // Avoid aggressive synthesis optimizations.
  for (genvar i = 0; i < 4; i++) begin : gen_a01_inv_buf
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_a1_inv_i (
      .in_i  ( a1_inv[i]     ),
      .out_o ( a1_inv_buf[i] )
    );
    caliptra_prim_buf #(
      .Width ( 4 )
    ) u_caliptra_prim_buf_a0_inv_i (
      .in_i  ( a0_inv[i]     ),
      .out_o ( a0_inv_buf[i] )
    );
  end

  // Note: a_inv is masked by s (= n), a was masked by m.
  assign a_inv = {a1_inv_buf[3], a0_inv_buf[3]};

endmodule

// SEC_CM: KEY.MASKING
module aes_sbox_canright_masked (
  input  aes_pkg::ciph_op_e op_i,
  input  logic [7:0]        data_i, // masked, the actual input data is data_i ^ mask_i
  input  logic [7:0]        mask_i, // input mask, independent from actual input data
  input  logic [7:0]        prd_i,  // pseudo-random data for remasking, independent of input mask
  output logic [7:0]        data_o, // masked, the actual output data is data_o ^ mask_o
  output logic [7:0]        mask_o  // output mask
);

  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  //////////////////////////
  // Masked Canright SBox //
  //////////////////////////

  logic [7:0] in_data_basis_x, out_data_basis_x;
  logic [7:0] in_mask_basis_x, out_mask_basis_x;

  // Convert data to normal basis X.
  assign in_data_basis_x = (op_i == CIPH_FWD) ? aes_mvm(data_i, A2X)         :
                           (op_i == CIPH_INV) ? aes_mvm(data_i ^ 8'h63, S2X) :
                                                aes_mvm(data_i, A2X);

  // For the masked Canright SBox, the output mask directly corresponds to the pseduo-random data
  // provided as input.
  assign mask_o = prd_i;

  // Convert masks to normal basis X.
  // The addition of constant 8'h63 following the affine transformation is skipped.
  assign in_mask_basis_x  = (op_i == CIPH_FWD) ? aes_mvm(mask_i, A2X) :
                            (op_i == CIPH_INV) ? aes_mvm(mask_i, S2X) :
                                                 aes_mvm(mask_i, A2X);

  // The output mask is converted in the opposite direction.
  assign out_mask_basis_x = (op_i == CIPH_INV) ? aes_mvm(mask_o, A2X) :
                            (op_i == CIPH_FWD) ? aes_mvm(mask_o, S2X) :
                                                 aes_mvm(mask_o, S2X);

  // Do the inversion in normal basis X.
  aes_masked_inverse_gf2p8 u_aes_masked_inverse_gf2p8 (
    .a     ( in_data_basis_x  ), // input
    .m     ( in_mask_basis_x  ), // input
    .n     ( out_mask_basis_x ), // input
    .a_inv ( out_data_basis_x )  // output
  );

  // Convert to basis S or A.
  assign data_o = (op_i == CIPH_FWD) ? (aes_mvm(out_data_basis_x, X2S) ^ 8'h63) :
                  (op_i == CIPH_INV) ? (aes_mvm(out_data_basis_x, X2A))         :
                                       (aes_mvm(out_data_basis_x, X2S) ^ 8'h63);

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES Canright SBox #4
//
// For details, see the technical report: Canright, "A very compact Rijndael S-box"
// available at https://hdl.handle.net/10945/25608

module aes_sbox_canright (
  input  aes_pkg::ciph_op_e op_i,
  input  logic [7:0]        data_i,
  output logic [7:0]        data_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  ///////////////
  // Functions //
  ///////////////

  // Inverse in GF(2^4), using normal basis [alpha^8, alpha^2]
  // (see Figure 12 in the technical report)
  function automatic logic [3:0] aes_inverse_gf2p4(logic [3:0] gamma);
    logic [3:0] delta;
    logic [1:0] a, b, c, d;
    a          = gamma[3:2] ^ gamma[1:0];
    b          = aes_mul_gf2p2(gamma[3:2], gamma[1:0]);
    c          = aes_scale_omega2_gf2p2(aes_square_gf2p2(a));
    d          = aes_square_gf2p2(c ^ b);
    delta[3:2] = aes_mul_gf2p2(d, gamma[1:0]);
    delta[1:0] = aes_mul_gf2p2(d, gamma[3:2]);
    return delta;
  endfunction

  // Inverse in GF(2^8), using normal basis [d^16, d]
  // (see Figure 11 in the technical report)
  function automatic logic [7:0] aes_inverse_gf2p8(logic [7:0] gamma);
    logic [7:0] delta;
    logic [3:0] a, b, c, d;
    a          = gamma[7:4] ^ gamma[3:0];
    b          = aes_mul_gf2p4(gamma[7:4], gamma[3:0]);
    c          = aes_square_scale_gf2p4_gf2p2(a);
    d          = aes_inverse_gf2p4(c ^ b);
    delta[7:4] = aes_mul_gf2p4(d, gamma[3:0]);
    delta[3:0] = aes_mul_gf2p4(d, gamma[7:4]);
    return delta;
  endfunction

  ///////////////////
  // Canright SBox //
  ///////////////////

  logic [7:0] data_basis_x, data_inverse;

  // Convert to normal basis X.
  assign data_basis_x = (op_i == CIPH_FWD) ? aes_mvm(data_i, A2X)         :
                        (op_i == CIPH_INV) ? aes_mvm(data_i ^ 8'h63, S2X) :
                                             aes_mvm(data_i, A2X);

  // Do the inversion in normal basis X.
  assign data_inverse = aes_inverse_gf2p8(data_basis_x);

  // Convert to basis S or A.
  assign data_o       = (op_i == CIPH_FWD) ? aes_mvm(data_inverse, X2S) ^ 8'h63 :
                        (op_i == CIPH_INV) ? aes_mvm(data_inverse, X2A) :
                                             aes_mvm(data_inverse, X2S) ^ 8'h63;

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES S-Box with First-Order Domain-Oriented Masking
//
// This is the unpipelined version using DOM-dep multipliers. It has a latency of 5 clock cycles
// and requires 28 bits of pseudo-random data per evaluation. Pipelining would only be beneficial
// when using
// - either a cipher core architecture with a data path smaller than 128 bit, i.e., where the
//   individual S-Boxes are evaluated more than once per round, or
// - a fully unrolled cipher core architecture for maximum throughput.
//
// Note: The DOM AES S-Box is built on top of the Canright masked S-Box without mask re-use.
//
// For details, see the following papers and reports:
// [1] Gross, "Domain-Oriented Masking: Compact Masked Hardware Implementations with Arbitrary
//     Protection Order" available at https://eprint.iacr.org/2016/486.pdf
// [2] Canright, "A very compact 'perfectly masked' S-box for AES (corrected)" available at
//     https://eprint.iacr.org/2009/011.pdf
// [3] Canright, "A very compact Rijndael S-box" available at https://hdl.handle.net/10945/25608
//
// Using the Coco-Alma tool in transient mode, this implementation has been formally verified to be
// secure against first-order side-channel analysis (SCA). For more information on the tool,
// refer to the following papers:
// [4] Gigerl, "COCO: Co-design and co-verification of masked software implementations on CPUs"
//     available at https://eprint.iacr.org/2020/1294.pdf
// [5] Bloem, "Formal verification of masked hardware implementations in the presence of glitches"
//     available at https://eprint.iacr.org/2017/897.pdf

///////////////////////////////////////////////////////////////////////////////////////////////////
// IMPORTANT NOTE:                                                                               //
//                            DO NOT USE THIS FOR SYNTHESIS BLINDLY!                             //
//                                                                                               //
// This implementation relies on primitive cells like caliptra_prim_buf/flop_en containing tool-specific  //
// synthesis attributes to prevent the synthesis tool from optimizing away/re-ordering registers //
// and to enforce the correct ordering of operations. Without the proper primitives, synthesis   //
// tools might heavily optimize the design. The result is likely insecure. Use with care.        //
///////////////////////////////////////////////////////////////////////////////////////////////////

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

// Packed struct for pseudo-random data (PRD) input. Stages 1, 3 and 4 require 8 bits each. Stage 2
// requires just 4 bits.
typedef struct packed {
  logic [7:0] prd_1;
  logic [3:0] prd_2;
  logic [7:0] prd_3;
  logic [7:0] prd_4;
} prd_in_t;

// Packed struct for pseudo-random data (PRD) output. Stages 2 and 3 produce 8 bits each. Stage 1
// produces just 4 bits.
typedef struct packed {
  logic [3:0] prd_1;
  logic [7:0] prd_2;
  logic [7:0] prd_3;
} prd_out_t;

// DOM-indep GF(2^N) multiplier, first-order masked.
// Computes (a_q ^ b_q) = (a_x ^ b_x) * (a_y ^ b_y), i.e. q = x * y using first-order
// domain-oriented masking. The sharings of x and y are required to be uniformly random and
// independent from each other.
// See Fig. 2 in [1].
module aes_dom_indep_mul_gf2pn #(
  parameter int unsigned NPower   = 4,
  parameter bit          Pipeline = 1'b0
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              we_i,
  input  logic [NPower-1:0] a_x,    // Share a of x
  input  logic [NPower-1:0] a_y,    // Share a of y
  input  logic [NPower-1:0] b_x,    // Share b of x
  input  logic [NPower-1:0] b_y,    // Share b of y
  input  logic [NPower-1:0] z_0,    // Randomness for resharing
  output logic [NPower-1:0] a_q,    // Share a of q
  output logic [NPower-1:0] b_q     // Share b of q
);

  import aes_sbox_canright_pkg::*;

  /////////////////
  // Calculation //
  /////////////////
  // Inner-domain terms
  logic [NPower-1:0] mul_ax_ay_d, mul_bx_by_d;
  if (NPower == 4) begin : gen_inner_mul_gf2p4
    assign mul_ax_ay_d = aes_mul_gf2p4(a_x, a_y);
    assign mul_bx_by_d = aes_mul_gf2p4(b_x, b_y);

  end else begin : gen_inner_mul_gf2p2
    assign mul_ax_ay_d = aes_mul_gf2p2(a_x, a_y);
    assign mul_bx_by_d = aes_mul_gf2p2(b_x, b_y);
  end

  // Cross-domain terms
  logic [NPower-1:0] mul_ax_by, mul_ay_bx;
  if (NPower == 4) begin : gen_cross_mul_gf2p4
    assign mul_ax_by = aes_mul_gf2p4(a_x, b_y);
    assign mul_ay_bx = aes_mul_gf2p4(a_y, b_x);

  end else begin : gen_cross_mul_gf2p2
    assign mul_ax_by = aes_mul_gf2p2(a_x, b_y);
    assign mul_ay_bx = aes_mul_gf2p2(a_y, b_x);
  end

  ///////////////
  // Resharing //
  ///////////////
  // Resharing of cross-domain terms
  logic [NPower-1:0] aq_z0_d, bq_z0_d;
  logic [NPower-1:0] aq_z0_q, bq_z0_q;
  assign aq_z0_d = z_0 ^ mul_ax_by;
  assign bq_z0_d = z_0 ^ mul_ay_bx;

  // Registers
  caliptra_prim_flop_en #(
    .Width      ( 2*NPower ),
    .ResetValue ( '0       )
  ) u_caliptra_prim_flop_abq_z0 (
    .clk_i  ( clk_i              ),
    .rst_ni ( rst_ni             ),
    .en_i   ( we_i               ),
    .d_i    ( {aq_z0_d, bq_z0_d} ),
    .q_o    ( {aq_z0_q, bq_z0_q} )
  );

  /////////////////////////
  // Optional Pipelining //
  /////////////////////////
  logic [NPower-1:0] mul_ax_ay, mul_bx_by;

  if (Pipeline == 1'b1) begin : gen_pipeline
    // Add pipeline registers on inner-domain terms prior to integration. This allows accepting new
    // input data every clock cycle and prevents SCA leakage occurring due to the integration of
    // reshared cross-domain terms with inner-domain terms derived from different input data.

    logic [NPower-1:0] mul_ax_ay_q, mul_bx_by_q;
    caliptra_prim_flop_en #(
      .Width      ( 2*NPower ),
      .ResetValue ( '0       )
    ) u_caliptra_prim_flop_mul_abx_aby (
      .clk_i  ( clk_i                      ),
      .rst_ni ( rst_ni                     ),
      .en_i   ( we_i                       ),
      .d_i    ( {mul_ax_ay_d, mul_bx_by_d} ),
      .q_o    ( {mul_ax_ay_q, mul_bx_by_q} )
    );

    assign mul_ax_ay = mul_ax_ay_q;
    assign mul_bx_by = mul_bx_by_q;

  end else begin : gen_no_pipeline
    // Do not add the optional pipeline registers on the inner-domain terms. This allows to save
    // some area in case the multiplier does not need to accept new data in every cycle. However,
    // this can cause SCA leakage as during the clock cycle in which new data arrives, the new
    // inner-domain terms are integrated with the previous, reshared cross-domain terms.

    // Avoid aggressive synthesis optimizations.
    logic [NPower-1:0] mul_ax_ay_buf, mul_bx_by_buf;
    caliptra_prim_buf #(
      .Width  ( 2*NPower )
    ) u_caliptra_prim_buf_mul_abx_aby (
      .in_i  ( {mul_ax_ay_d,   mul_bx_by_d}   ),
      .out_o ( {mul_ax_ay_buf, mul_bx_by_buf} )
    );

    assign mul_ax_ay = mul_ax_ay_buf;
    assign mul_bx_by = mul_bx_by_buf;
  end

  /////////////////
  // Integration //
  /////////////////
  assign a_q = mul_ax_ay ^ aq_z0_q;
  assign b_q = mul_bx_by ^ bq_z0_q;

  // Only GF(2^4) and GF(2^2) is supported.
  `CALIPTRA_ASSERT_INIT(AesDomIndepMulPower, NPower == 4 || NPower == 2)

endmodule

// DOM-dep GF(2^N) multiplier, first-order masked.
// Computes (a_q ^ b_q) = (a_x ^ b_x) * (a_y ^ b_y), i.e. q = x * y using first-order
// domain-oriented masking. The sharings of x and y are NOT required to be independent from each
// other. This is the un-optimized version consuming 3 times N bits of randomness for blinding and
// resharing. It is not used in the design but we keep it for reference.
// See Fig. 4 and Formulas 8 - 11 in [1].
module aes_dom_dep_mul_gf2pn_unopt #(
  parameter int unsigned NPower   = 4,
  parameter bit          Pipeline = 1'b0
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              we_i,
  input  logic [NPower-1:0] a_x,    // Share a of x
  input  logic [NPower-1:0] a_y,    // Share a of y
  input  logic [NPower-1:0] b_x,    // Share b of x
  input  logic [NPower-1:0] b_y,    // Share b of y
  input  logic [NPower-1:0] a_z,    // Randomness for blinding
  input  logic [NPower-1:0] b_z,    // Randomness for blinding
  input  logic [NPower-1:0] z_0,    // Randomness for resharing
  output logic [NPower-1:0] a_q,    // Share a of q
  output logic [NPower-1:0] b_q     // Share b of q
);

  import aes_sbox_canright_pkg::*;

  //////////////
  // Blinding //
  //////////////
  // Blinding of y by z.
  logic [NPower-1:0] a_yz_d, b_yz_d;
  logic [NPower-1:0] a_yz_q, b_yz_q;
  assign a_yz_d = a_y ^ a_z;
  assign b_yz_d = b_y ^ b_z;

  // Registers
  caliptra_prim_flop_en #(
    .Width      ( 2*NPower ),
    .ResetValue ( '0       )
  ) u_caliptra_prim_flop_ab_yz (
    .clk_i  ( clk_i            ),
    .rst_ni ( rst_ni           ),
    .en_i   ( we_i             ),
    .d_i    ( {a_yz_d, b_yz_d} ),
    .q_o    ( {a_yz_q, b_yz_q} )
  );

  ////////////////
  // Correction //
  ////////////////
  logic [NPower-1:0] a_mul_x_z, b_mul_x_z;
  aes_dom_indep_mul_gf2pn #(
    .NPower   ( NPower   ),
    .Pipeline ( Pipeline )
  ) u_aes_dom_indep_mul_gf2pn (
    .clk_i  ( clk_i     ),
    .rst_ni ( rst_ni    ),
    .we_i   ( we_i      ),
    .a_x    ( a_x       ), // Share a of x
    .a_y    ( a_z       ), // Share a of z
    .b_x    ( b_x       ), // Share b of x
    .b_y    ( b_z       ), // Share b of z
    .z_0    ( z_0       ), // Randomness for resharing
    .a_q    ( a_mul_x_z ), // Share a of x * z
    .b_q    ( b_mul_x_z )  // Share b of x * z
  );

  /////////////////////////
  // Optional Pipelining //
  /////////////////////////
  logic [NPower-1:0] a_x_calc, b_x_calc;

  if (Pipeline == 1'b1) begin : gen_pipeline
    // Add pipeline registers for input x. This allows accepting new input data every clock cycle
    // and prevents SCA leakage occurring due to the multiplication of input x with b belonging to
    // different clock cycles.

    logic [NPower-1:0] a_x_q, b_x_q;
    caliptra_prim_flop_en #(
      .Width      ( 2*NPower ),
      .ResetValue ( '0       )
    ) u_caliptra_prim_flop_ab_x (
      .clk_i  ( clk_i          ),
      .rst_ni ( rst_ni         ),
      .en_i   ( we_i           ),
      .d_i    ( {a_x,   b_x}   ),
      .q_o    ( {a_x_q, b_x_q} )
    );

    assign a_x_calc = a_x_q;
    assign b_x_calc = b_x_q;

  end else begin : gen_no_pipeline
    // Do not add the optional pipeline registers for input x. This allows to save some area in
    // case the multiplier does not need to accept new data in every cycle. However, this can cause
    // SCA leakage as during the clock cycle in which new data arrives, the new x input is
    // multiplied with the previous b.

    assign a_x_calc = a_x;
    assign b_x_calc = b_x;
  end

  /////////////////
  // Calculation //
  /////////////////
  // Combine shares of blinded y to obtain b.
  logic [NPower-1:0] b;
  assign b = a_yz_q ^ b_yz_q;

  logic [NPower-1:0] a_mul_ax_b, b_mul_bx_b;
  if (NPower == 4) begin : gen_mul_gf2p4
    assign a_mul_ax_b = aes_mul_gf2p4(a_x_calc, b);
    assign b_mul_bx_b = aes_mul_gf2p4(b_x_calc, b);

  end else begin : gen_mul_gf2p2
    assign a_mul_ax_b = aes_mul_gf2p2(a_x_calc, b);
    assign b_mul_bx_b = aes_mul_gf2p2(b_x_calc, b);
  end

  /////////////////
  // Integration //
  /////////////////
  assign a_q = a_mul_x_z ^ a_mul_ax_b;
  assign b_q = b_mul_x_z ^ b_mul_bx_b;

  // Only GF(2^4) and GF(2^2) is supported.
  `CALIPTRA_ASSERT_INIT(AesDomDepMulUnoptPower, NPower == 4 || NPower == 2)

endmodule

// DOM-dep GF(2^N) multiplier, first-order masked.
// Computes (a_q ^ b_q) = (a_x ^ b_x) * (a_y ^ b_y), i.e. q = x * y using first-order
// domain-oriented masking. The sharings of x and y are NOT required to be independent from each
// other. This is the optimized version consuming 2 instead of 3 times N bits of randomness for
// blinding and resharing.
// See Formula 12 in [1].
module aes_dom_dep_mul_gf2pn #(
  parameter int unsigned NPower      = 4,
  parameter bit          Pipeline    = 1'b0,
  parameter bit          PreDomIndep = 1'b0 // 1'b0: Not followed by an un-pipelined DOM-indep
                                            //       multiplier, this enables additional area
                                            //       optimizations
                                            // 1'b1: Directly followed by an un-pipelined
                                            //       DOM-indep multiplier, this is the version
                                            //       discussed in [1].
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic                we_i,
  input  logic   [NPower-1:0] a_x,    // Share a of x
  input  logic   [NPower-1:0] a_y,    // Share a of y
  input  logic   [NPower-1:0] b_x,    // Share b of x
  input  logic   [NPower-1:0] b_y,    // Share b of y
  input  logic   [NPower-1:0] a_x_q,  // Share a of x, pipelined (for Pipeline=1 or PreDomIndep=1)
  input  logic   [NPower-1:0] a_y_q,  // Share a of y, pipelined (for Pipeline=1)
  input  logic   [NPower-1:0] b_x_q,  // Share b of x, pipelined (for Pipeline=1 or PreDomIndep=1)
  input  logic   [NPower-1:0] b_y_q,  // Share b of y, pipelined (for Pipeline=1)
  input  logic   [NPower-1:0] z_0,    // Randomness for blinding
  input  logic   [NPower-1:0] z_1,    // Randomness for resharing
  output logic   [NPower-1:0] a_q,    // Share a of q
  output logic   [NPower-1:0] b_q,    // Share b of q
  output logic [2*NPower-1:0] prd_o   // Randomness for use in another S-Box instance
);

  import aes_sbox_canright_pkg::*;

  //////////////
  // Blinding //
  //////////////
  // Blinding of y by z_0.
  logic [NPower-1:0] a_yz0_d, b_yz0_d;
  logic [NPower-1:0] a_yz0_q, b_yz0_q;
  assign a_yz0_d = a_y ^ z_0;
  assign b_yz0_d = b_y ^ z_0;

  // Registers
  caliptra_prim_flop_en #(
    .Width      ( 2*NPower ),
    .ResetValue ( '0       )
  ) u_caliptra_prim_flop_ab_yz0 (
    .clk_i  ( clk_i              ),
    .rst_ni ( rst_ni             ),
    .en_i   ( we_i               ),
    .d_i    ( {a_yz0_d, b_yz0_d} ),
    .q_o    ( {a_yz0_q, b_yz0_q} )
  );

  ////////////////
  // Correction //
  ////////////////
  // Basically, this a DOM-indep multiplier with:
  // - a_x = a_x, b_x = b_x, and
  // - a_y = z_0, b_y = 0 (constant),
  // which allows for further optimizations.

  // Calculation
  logic [NPower-1:0] mul_ax_z0, mul_bx_z0;
  if (NPower == 4) begin : gen_corr_mul_gf2p4
    assign mul_ax_z0 = aes_mul_gf2p4(a_x, z_0);
    assign mul_bx_z0 = aes_mul_gf2p4(b_x, z_0);

  end else begin : gen_corr_mul_gf2p2
    assign mul_ax_z0 = aes_mul_gf2p2(a_x, z_0);
    assign mul_bx_z0 = aes_mul_gf2p2(b_x, z_0);
  end

  // Avoid aggressive synthesis optimizations.
  logic [NPower-1:0] mul_ax_z0_buf, mul_bx_z0_buf;
  caliptra_prim_buf #(
    .Width ( 2*NPower )
  ) u_caliptra_prim_buf_mul_abx_z0 (
    .in_i  ( {mul_ax_z0,     mul_bx_z0}     ),
    .out_o ( {mul_ax_z0_buf, mul_bx_z0_buf} )
  );

  // Resharing
  logic [NPower-1:0] axz0_z1_d, bxz0_z1_d;
  logic [NPower-1:0] axz0_z1_q, bxz0_z1_q;
  assign axz0_z1_d = mul_ax_z0_buf ^ z_1;
  assign bxz0_z1_d = mul_bx_z0_buf ^ z_1;

  // Registers
  caliptra_prim_flop_en #(
    .Width      ( 2*NPower ),
    .ResetValue ( '0       )
  ) u_caliptra_prim_flop_abxz0_z1 (
    .clk_i  ( clk_i                  ),
    .rst_ni ( rst_ni                 ),
    .en_i   ( we_i                   ),
    .d_i    ( {axz0_z1_d, bxz0_z1_d} ),
    .q_o    ( {axz0_z1_q, bxz0_z1_q} )
  );

  // Use intermediate results for generating PRD for another S-Box instance.
  // Use one share only. Directly use output of flops updating with we_i.
  // These intermediate results are obtained by remasking b_y and mul_bx_z0 with z_0 and z_1,
  // respectively. Since z_0/1 are uniformly distributed and independent of b_y and mul_bx_z0,
  // the intermediate results are also uniformly distributed and independent of b_y and mul_bx_z0.
  // For details, see Lemma 1 in [2].
  assign prd_o = {b_yz0_q, bxz0_z1_q};

  /////////////////////////
  // Optional Pipelining //
  /////////////////////////
  logic [NPower-1:0] a_x_calc, b_x_calc, a_y_calc, b_y_calc;

  if (Pipeline == 1'b1 && PreDomIndep != 1'b1) begin : gen_pipeline_use
    // Use pipelined inputs x and y. This allows accepting new input data every clock cycle and
    // prevents SCA leakage occurring due to the multiplication of inputs x and y with d_b
    // belonging to different clock cycles.
    //
    // The PreDomIndep variant uses the pipelined inputs directly.

    assign a_x_calc = a_x_q;
    assign b_x_calc = b_x_q;
    assign a_y_calc = a_y_q;
    assign b_y_calc = b_y_q;

  end else begin : gen_no_pipeline_use
    // Do not use pipelined inputs x and y. This allows to save some area in case the multiplier
    // does not need to accept new data in every cycle. However, this can cause SCA leakage as
    // during the clock cycle in which new data arrives, the new x and y inputs are multiplied
    // with the previous d_b.

    assign a_x_calc = a_x;
    assign b_x_calc = b_x;
    assign a_y_calc = a_y;
    assign b_y_calc = b_y;

    // Tie off unused signals.
    if (PreDomIndep != 1'b1) begin : gen_ab_x_q
      logic [NPower-1:0] unused_a_x_q, unused_b_x_q;
      assign unused_a_x_q = a_x_q;
      assign unused_b_x_q = b_x_q;
    end
    logic [NPower-1:0] unused_a_y_q, unused_b_y_q;
    assign unused_a_y_q = a_y_q;
    assign unused_b_y_q = b_y_q;
  end

  ///////////////////////////////
  // Calculation & Integration //
  ///////////////////////////////
  // Compute b. Note that unlike for the unoptimized implementation, we don't combine the blinded
  // shares of y to obtain a single b value. Intstead, every domain d gets its own version of b:
  //
  //   d_b = d_y ^ _D_y_z0
  //
  // where _D_y_z0 corresponds to the sum of all domains of y except for domain d, each
  // individually blinded by z0 (needs to happen before the register bank). This optimization
  // is only suitable for first-order masking.
  // See Formula 12 in [1].

  if (PreDomIndep == 1'b1) begin : gen_pre_dom_indep
    // This DOM-dep multiplier is directly followed by an un-pipelined DOM-indep multiplier. To
    // prevent SCA leakage in the un-pipelined DOM-indep multiplier, the d_y and _D_y_z0 parts of
    // d_b need to be individually multiplied with input x and then the results need to be
    // integrated (summed up) on a per-domain basis.

    // d_y part: Inner-domain terms of x * y
    logic [NPower-1:0] mul_ax_ay_d, mul_bx_by_d;
    logic [NPower-1:0] mul_ax_ay_q, mul_bx_by_q;
    if (NPower == 4) begin : gen_inner_mul_gf2p4
      assign mul_ax_ay_d = aes_mul_gf2p4(a_x_calc, a_y_calc);
      assign mul_bx_by_d = aes_mul_gf2p4(b_x_calc, b_y_calc);

    end else begin : gen_inner_mul_gf2p2
      assign mul_ax_ay_d = aes_mul_gf2p2(a_x_calc, a_y_calc);
      assign mul_bx_by_d = aes_mul_gf2p2(b_x_calc, b_y_calc);
    end

    // Registers
    caliptra_prim_flop_en #(
      .Width      ( 2*NPower ),
      .ResetValue ( '0       )
    ) u_caliptra_prim_flop_mul_abx_aby (
      .clk_i  ( clk_i                      ),
      .rst_ni ( rst_ni                     ),
      .en_i   ( we_i                       ),
      .d_i    ( {mul_ax_ay_d, mul_bx_by_d} ),
      .q_o    ( {mul_ax_ay_q, mul_bx_by_q} )
    );

    // _D_y_z0 part: Cross-domain terms: d_x * _D_y_z0
    // Need to use registered version of input x.
    logic [NPower-1:0] mul_ax_byz0, mul_bx_ayz0;
    if (NPower == 4) begin : gen_cross_mul_gf2p4
      assign mul_ax_byz0 = aes_mul_gf2p4(a_x_q, b_yz0_q);
      assign mul_bx_ayz0 = aes_mul_gf2p4(b_x_q, a_yz0_q);

    end else begin : gen_cross_mul_gf2p2
      assign mul_ax_byz0 = aes_mul_gf2p2(a_x_q, b_yz0_q);
      assign mul_bx_ayz0 = aes_mul_gf2p2(b_x_q, a_yz0_q);
    end

    // Avoid aggressive synthesis optimizations.
    logic [NPower-1:0] mul_ax_byz0_buf, mul_bx_ayz0_buf;
    caliptra_prim_buf #(
      .Width ( 2*NPower )
    ) u_caliptra_prim_buf_mul_abx_bayz0 (
      .in_i  ( {mul_ax_byz0,     mul_bx_ayz0}     ),
      .out_o ( {mul_ax_byz0_buf, mul_bx_ayz0_buf} )
    );

    // Integration
    assign a_q = axz0_z1_q ^ mul_ax_ay_q ^ mul_ax_byz0_buf;
    assign b_q = bxz0_z1_q ^ mul_bx_by_q ^ mul_bx_ayz0_buf;

  end else begin : gen_not_pre_dom_indep
    // This DOM-dep multiplier is not directly followed by an un-pipelined DOM-indep multiplier. As
    // a result, the the d_y and _D_y_z0 parts of d_b can be summed up prior to the multiplication
    // with input x which allows saving 2 GF multipliers.

    // Sum up d_y and _D_y_z0.
    logic [NPower-1:0] a_b, b_b;
    assign a_b = a_y_calc ^ b_yz0_q;
    assign b_b = b_y_calc ^ a_yz0_q;

    // Avoid aggressive synthesis optimizations.
    logic [NPower-1:0] a_b_buf, b_b_buf;
    caliptra_prim_buf #(
      .Width ( 2*NPower )
    ) u_caliptra_prim_buf_ab_b (
      .in_i  ( {a_b,     b_b}     ),
      .out_o ( {a_b_buf, b_b_buf} )
    );

    // GF multiplications
    logic [NPower-1:0] a_mul_ax_b, b_mul_bx_b;
    if (NPower == 4) begin : gen_mul_gf2p4
      assign a_mul_ax_b = aes_mul_gf2p4(a_x_calc, a_b_buf);
      assign b_mul_bx_b = aes_mul_gf2p4(b_x_calc, b_b_buf);
    end else begin : gen_mul_gf2p2
      assign a_mul_ax_b = aes_mul_gf2p2(a_x_calc, a_b_buf);
      assign b_mul_bx_b = aes_mul_gf2p2(b_x_calc, b_b_buf);
    end

    // Avoid aggressive synthesis optimizations.
    logic [NPower-1:0] a_mul_ax_b_buf, b_mul_bx_b_buf;
    caliptra_prim_buf #(
      .Width ( 2*NPower )
    ) u_caliptra_prim_buf_ab_mul_abx_b (
      .in_i  ( {a_mul_ax_b,     b_mul_bx_b}     ),
      .out_o ( {a_mul_ax_b_buf, b_mul_bx_b_buf} )
    );

    // Integration
    assign a_q = axz0_z1_q ^ a_mul_ax_b_buf;
    assign b_q = bxz0_z1_q ^ b_mul_bx_b_buf;
  end

  // Only GF(2^4) and GF(2^2) is supported.
  `CALIPTRA_ASSERT_INIT(AesDomDepMulPower, NPower == 4 || NPower == 2)

endmodule

// Inverse in GF(2^4) using first-order domain-oriented masking and normal basis [z^4, z].
// See Fig. 6 in [2] (grey block, Stages 2 and 3) and Formulas 6, 13, 14, 15, 16, 17 in [2].
module aes_dom_inverse_gf2p4 #(
  parameter bit PipelineMul = 1'b1
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic  [1:0] we_i,
  input  logic  [3:0] a_gamma,
  input  logic  [3:0] b_gamma,
  input  logic  [3:0] prd_2_i,
  input  logic  [7:0] prd_3_i,
  output logic  [3:0] a_gamma_inv,
  output logic  [3:0] b_gamma_inv,
  output logic  [7:0] prd_2_o,
  output logic  [7:0] prd_3_o
);

  import aes_sbox_canright_pkg::*;

  /////////////
  // Stage 2 //
  /////////////
  // Formula 13 in [2].

  logic [1:0] a_gamma1, a_gamma0, b_gamma1, b_gamma0, a_gamma1_gamma0, b_gamma1_gamma0;
  assign a_gamma1 = a_gamma[3:2];
  assign a_gamma0 = a_gamma[1:0];
  assign b_gamma1 = b_gamma[3:2];
  assign b_gamma0 = b_gamma[1:0];

  logic [1:0] a_gamma_ss_d, b_gamma_ss_d;
  logic [1:0] a_gamma_ss_q, b_gamma_ss_q;
  assign a_gamma_ss_d = aes_scale_omega2_gf2p2(aes_square_gf2p2(a_gamma1 ^ a_gamma0));
  assign b_gamma_ss_d = aes_scale_omega2_gf2p2(aes_square_gf2p2(b_gamma1 ^ b_gamma0));
  caliptra_prim_flop_en #(
    .Width      ( 4  ),
    .ResetValue ( '0 )
  ) u_caliptra_prim_flop_ab_gamma_ss (
    .clk_i  ( clk_i                        ),
    .rst_ni ( rst_ni                       ),
    .en_i   ( we_i[0]                      ),
    .d_i    ( {a_gamma_ss_d, b_gamma_ss_d} ),
    .q_o    ( {a_gamma_ss_q, b_gamma_ss_q} )
  );

  logic [1:0] a_gamma1_q, a_gamma0_q, b_gamma1_q, b_gamma0_q;
  caliptra_prim_flop_en #(
    .Width      ( 8  ),
    .ResetValue ( '0 )
  ) u_caliptra_prim_flop_ab_gamma10 (
    .clk_i  ( clk_i                                            ),
    .rst_ni ( rst_ni                                           ),
    .en_i   ( we_i[0]                                          ),
    .d_i    ( {a_gamma1,   a_gamma0,   b_gamma1,   b_gamma0}   ),
    .q_o    ( {a_gamma1_q, a_gamma0_q, b_gamma1_q, b_gamma0_q} )
  );

  logic [3:0] b_gamma10_prd2;
  aes_dom_dep_mul_gf2pn #(
    .NPower      ( 2           ),
    .Pipeline    ( PipelineMul ),
    .PreDomIndep ( 1'b0        )
  ) u_aes_dom_mul_gamma1_gamma0 (
    .clk_i  ( clk_i           ),
    .rst_ni ( rst_ni          ),
    .we_i   ( we_i[0]         ),
    .a_x    ( a_gamma1        ), // Share a of x
    .a_y    ( a_gamma0        ), // Share a of y
    .b_x    ( b_gamma1        ), // Share b of x
    .b_y    ( b_gamma0        ), // Share b of y
    .a_x_q  ( a_gamma1_q      ), // Share a of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .a_y_q  ( a_gamma0_q      ), // Share a of y, pipelined (for Pipeline=1)
    .b_x_q  ( b_gamma1_q      ), // Share b of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .b_y_q  ( b_gamma0_q      ), // Share b of y, pipelined (for Pipeline=1)
    .z_0    ( prd_2_i[1:0]    ), // Randomness for blinding
    .z_1    ( prd_2_i[3:2]    ), // Randomness for resharing
    .a_q    ( a_gamma1_gamma0 ), // Share a of q
    .b_q    ( b_gamma1_gamma0 ), // Share b of q
    .prd_o  ( b_gamma10_prd2  )  // Randomness for use in another S-Box instance
  );

  // Use intermediate results for generating PRD for Stage 3 of another S-Box instance.
  // Use one share only. Directly use output of flops updating with we_i[0].
  // b_gamma10_prd2 is based on b_gamma1_q, b_gamma0_q but XORed with prd_2_i, thus uniformly
  // distributed and independent of b_gamma1/0_q (See Lemma 1 in [2]).
  //
  // In Stage 3 of another S-Box instance, the MSBs and LSBs of the term below are used:
  // 1. as randomness in the DOM-dep multipliers u_aes_dom_mul_omega_gamma1/0, and
  // 2. to generate randomness for the DOM-indep multipliers u_aes_dom_mul_theta_y1/0 in Stage 4 of
  //    yet another S-Box instance, respectively.
  // Without interleaving b_gamma1/0_q as well as the upper and lower halves of b_gamma10_prd2 here,
  // a glitch on the write-enable signal on the input pipeline register of these DOM-indep
  // multipliers may result in undesirable SCA leakage.
  assign prd_2_o = {b_gamma1_q, b_gamma10_prd2[3:2], b_gamma0_q, b_gamma10_prd2[1:0]};

  /////////////
  // Stage 3 //
  /////////////

  // Formulas 14 and 15 in [2].
  logic [1:0] a_omega, b_omega;
  assign a_omega = aes_square_gf2p2(a_gamma1_gamma0 ^ a_gamma_ss_q);
  assign b_omega = aes_square_gf2p2(b_gamma1_gamma0 ^ b_gamma_ss_q);

  // Avoid aggressive synthesis optimizations.
  logic [1:0] a_omega_buf, b_omega_buf;
  caliptra_prim_buf #(
    .Width ( 4 )
  ) u_caliptra_prim_buf_ab_omega (
    .in_i  ( {a_omega,     b_omega}     ),
    .out_o ( {a_omega_buf, b_omega_buf} )
  );

  // Pipeline registers
  logic [1:0] a_gamma1_qq, a_gamma0_qq, b_gamma1_qq, b_gamma0_qq, a_omega_buf_q, b_omega_buf_q;
  if (PipelineMul == 1'b1) begin: gen_caliptra_prim_flop_omega_gamma10
    // We instantiate the input pipeline registers for the DOM-dep multiplier outside of the
    // multiplier to enable sharing of pipeline registers where applicable.

    caliptra_prim_flop_en #(
      .Width      ( 8  ),
      .ResetValue ( '0 )
    ) u_caliptra_prim_flop_ab_gamma10_q (
      .clk_i  ( clk_i                                                ),
      .rst_ni ( rst_ni                                               ),
      .en_i   ( we_i[1]                                              ),
      .d_i    ( {a_gamma1_q,  a_gamma0_q,  b_gamma1_q,  b_gamma0_q}  ),
      .q_o    ( {a_gamma1_qq, a_gamma0_qq, b_gamma1_qq, b_gamma0_qq} )
    );

    // These inputs are used by both DOM-dep multipliers below.
    caliptra_prim_flop_en #(
      .Width      ( 4  ),
      .ResetValue ( '0 )
    ) u_caliptra_prim_flop_ab_omega_buf (
      .clk_i  ( clk_i                          ),
      .rst_ni ( rst_ni                         ),
      .en_i   ( we_i[1]                        ),
      .d_i    ( {a_omega_buf,   b_omega_buf}   ),
      .q_o    ( {a_omega_buf_q, b_omega_buf_q} )
    );

  end else begin : gen_no_caliptra_prim_flop_ab_y10
    // When using un-pipelined multipliers, there is no need to insert additional registers.
    // We drive the corresponding inputs to 0 to make sure the functionality isn't correct in case
    // the pipeliend inputs are erroneously used.

    assign a_gamma1_qq = '0;
    assign a_gamma0_qq = '0;
    assign b_gamma1_qq = '0;
    assign b_gamma0_qq = '0;
    assign a_omega_buf_q = '0;
    assign b_omega_buf_q = '0;
  end

  // Formulas 16 and 17 in [2].
  logic [3:0] b_gamma1_omega_prd3;
  aes_dom_dep_mul_gf2pn #(
    .NPower      ( 2           ),
    .Pipeline    ( PipelineMul ),
    .PreDomIndep ( 1'b0        )
  ) u_aes_dom_mul_omega_gamma1 (
    .clk_i  ( clk_i               ),
    .rst_ni ( rst_ni              ),
    .we_i   ( we_i[1]             ),
    .a_x    ( a_gamma1_q          ), // Share a of x
    .a_y    ( a_omega_buf         ), // Share a of y
    .b_x    ( b_gamma1_q          ), // Share b of x
    .b_y    ( b_omega_buf         ), // Share b of y
    .a_x_q  ( a_gamma1_qq         ), // Share a of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .a_y_q  ( a_omega_buf_q       ), // Share a of y, pipelined (for Pipeline=1)
    .b_x_q  ( b_gamma1_qq         ), // Share b of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .b_y_q  ( b_omega_buf_q       ), // Share b of y, pipelined (for Pipeline=1)
    .z_0    ( prd_3_i[5:4]        ), // Randomness for blinding
    .z_1    ( prd_3_i[7:6]        ), // Randomness for resharing
    .a_q    ( a_gamma_inv[1:0]    ), // Share a of q
    .b_q    ( b_gamma_inv[1:0]    ), // Share b of q
    .prd_o  ( b_gamma1_omega_prd3 )  // Randomness for use in another S-Box instance
  );

  logic [3:0] b_gamma0_omega_prd3;
  aes_dom_dep_mul_gf2pn #(
    .NPower      ( 2           ),
    .Pipeline    ( PipelineMul ),
    .PreDomIndep ( 1'b0        )
  ) u_aes_dom_mul_omega_gamma0 (
    .clk_i  ( clk_i               ),
    .rst_ni ( rst_ni              ),
    .we_i   ( we_i[1]             ),
    .a_x    ( a_omega_buf         ), // Share a of x
    .a_y    ( a_gamma0_q          ), // Share a of y
    .b_x    ( b_omega_buf         ), // Share b of x
    .b_y    ( b_gamma0_q          ), // Share b of y
    .a_x_q  ( a_omega_buf_q       ), // Share a of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .a_y_q  ( a_gamma0_qq         ), // Share a of y, pipelined (for Pipeline=1)
    .b_x_q  ( b_omega_buf_q       ), // Share b of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .b_y_q  ( b_gamma0_qq         ), // Share b of y, pipelined (for Pipeline=1)
    .z_0    ( prd_3_i[1:0]        ), // Randomness for blinding
    .z_1    ( prd_3_i[3:2]        ), // Randomness for resharing
    .a_q    ( a_gamma_inv[3:2]    ), // Share a of q
    .b_q    ( b_gamma_inv[3:2]    ), // Share b of q
    .prd_o  ( b_gamma0_omega_prd3 )  // Randomness for use in another S-Box instance
  );

  // Use intermediate results for generating PRD for Stage 4 of another S-Box instance.
  // Use one share only. Directly use output of flops updating with we_i[1].
  // b_gamma1/0_omega_prd3 are both based on b_omega but XORed with differend parts of prd_3_i,
  // thus uniformly distributed and independent of b_omega (see Lemma 1 in [2]).
  assign prd_3_o = {b_gamma1_omega_prd3, b_gamma0_omega_prd3};

endmodule

// Inverse in GF(2^8) using first-order domain-oriented masking and normal basis [y^16, y].
// See Fig. 6 in [1] and Formulas 3, 12, 18 and 19 in [2].
module aes_dom_inverse_gf2p8 #(
  parameter bit PipelineMul = 1'b1
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic  [3:0] we_i,
  input  logic  [7:0] a_y,     // input data masked by b_y
  input  logic  [7:0] b_y,     // input mask
  input  prd_in_t     prd_i,   // pseudo-random data, e.g. for intermediate masks
  output logic  [7:0] a_y_inv, // output data masked by b_y_inv
  output logic  [7:0] b_y_inv, // output mask
  output prd_out_t    prd_o    // pseudo-random data, e.g. for use in another S-Box instance
);

  import aes_sbox_canright_pkg::*;

  /////////////
  // Stage 1 //
  /////////////
  // Formula 12 in [2].

  logic [3:0] a_y1, a_y0, b_y1, b_y0, a_y1_y0, b_y1_y0;
  assign a_y1 = a_y[7:4];
  assign a_y0 = a_y[3:0];
  assign b_y1 = b_y[7:4];
  assign b_y0 = b_y[3:0];

  logic [3:0] a_y_ss_d, b_y_ss_d;
  logic [3:0] a_y_ss_q, b_y_ss_q;
  assign a_y_ss_d = aes_square_scale_gf2p4_gf2p2(a_y1 ^ a_y0);
  assign b_y_ss_d = aes_square_scale_gf2p4_gf2p2(b_y1 ^ b_y0);
  caliptra_prim_flop_en #(
    .Width      ( 8  ),
    .ResetValue ( '0 )
  ) u_caliptra_prim_flop_ab_y_ss (
    .clk_i  ( clk_i                ),
    .rst_ni ( rst_ni               ),
    .en_i   ( we_i[0]              ),
    .d_i    ( {a_y_ss_d, b_y_ss_d} ),
    .q_o    ( {a_y_ss_q, b_y_ss_q} )
  );

  logic [3:0] a_y1_q, a_y0_q, b_y1_q, b_y0_q;
  if (PipelineMul == 1'b1) begin: gen_caliptra_prim_flop_ab_y10
    // We instantiate the input pipeline registers for the DOM-dep multiplier outside of the
    // multiplier to enable sharing of pipeline registers where applicable.

    caliptra_prim_flop_en #(
      .Width      ( 16  ),
      .ResetValue ( '0  )
    ) u_caliptra_prim_flop_ab_y10 (
      .clk_i  ( clk_i                            ),
      .rst_ni ( rst_ni                           ),
      .en_i   ( we_i[0]                          ),
      .d_i    ( {a_y1,   a_y0,   b_y1,   b_y0}   ),
      .q_o    ( {a_y1_q, a_y0_q, b_y1_q, b_y0_q} )
    );

  end else begin : gen_no_caliptra_prim_flop_ab_y10
    // When using un-pipelined multipliers, there is no need to insert additional registers.
    // We drive the corresponding inputs to 0 to make sure the functionality isn't correct in case
    // the pipeliend inputs are erroneously used.

    assign a_y1_q = '0;
    assign a_y0_q = '0;
    assign b_y1_q = '0;
    assign b_y0_q = '0;
  end

  logic [7:0] b_y10_prd1;
  aes_dom_dep_mul_gf2pn #(
    .NPower      ( 4           ),
    .Pipeline    ( PipelineMul ),
    .PreDomIndep ( 1'b0        )
  ) u_aes_dom_mul_y1_y0 (
    .clk_i  ( clk_i            ),
    .rst_ni ( rst_ni           ),
    .we_i   ( we_i[0]          ),
    .a_x    ( a_y1             ), // Share a of x
    .a_y    ( a_y0             ), // Share a of y
    .b_x    ( b_y1             ), // Share b of x
    .b_y    ( b_y0             ), // Share b of y
    .a_x_q  ( a_y1_q           ), // Share a of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .a_y_q  ( a_y0_q           ), // Share a of y, pipelined (for Pipeline=1)
    .b_x_q  ( b_y1_q           ), // Share b of x, pipelined (for Pipeline=1 or PreDomIndep=1)
    .b_y_q  ( b_y0_q           ), // Share b of y, pipelined (for Pipeline=1)
    .z_0    ( prd_i.prd_1[3:0] ), // Randomness for blinding
    .z_1    ( prd_i.prd_1[7:4] ), // Randomness for resharing
    .a_q    ( a_y1_y0          ), // Share a of q
    .b_q    ( b_y1_y0          ), // Share b of q
    .prd_o  ( b_y10_prd1       )  // Randomness for use in another S-Box instance
  );

  logic [3:0] a_gamma, b_gamma;
  assign a_gamma = a_y_ss_q ^ a_y1_y0;
  assign b_gamma = b_y_ss_q ^ b_y1_y0;

  // Avoid aggressive synthesis optimizations.
  logic [3:0] a_gamma_buf, b_gamma_buf;
  caliptra_prim_buf #(
    .Width ( 8 )
  ) u_caliptra_prim_buf_ab_gamma (
    .in_i  ( {a_gamma,     b_gamma}     ),
    .out_o ( {a_gamma_buf, b_gamma_buf} )
  );

  // Use intermediate results for generating PRD for Stage 2 of another S-Box instance.
  // Use one share only. Directly use output of flops updating with we_i[0].
  // b_y10_prd1 is based on b_y and XORed with prd_1. We just use the lower part involving a
  // non-linear element.
  assign prd_o.prd_1 = b_y10_prd1[3:0];
  logic [3:0] unused_prd;
  assign unused_prd  = b_y10_prd1[7:4];

  ////////////////////
  // Stages 2 and 3 //
  ////////////////////

  logic [3:0] a_theta, b_theta;

  // a_gamma is masked by b_gamma, a_gamma_inv is masked by b_gamma_inv.
  aes_dom_inverse_gf2p4 #(
    .PipelineMul ( PipelineMul )
  ) u_aes_dom_inverse_gf2p4 (
    .clk_i       ( clk_i       ),
    .rst_ni      ( rst_ni      ),
    .we_i        ( we_i[2:1]   ),
    .a_gamma     ( a_gamma_buf ),
    .b_gamma     ( b_gamma_buf ),
    .prd_2_i     ( prd_i.prd_2 ),
    .prd_3_i     ( prd_i.prd_3 ),
    .a_gamma_inv ( a_theta     ),
    .b_gamma_inv ( b_theta     ),
    .prd_2_o     ( prd_o.prd_2 ),
    .prd_3_o     ( prd_o.prd_3 )
  );

  /////////////
  // Stage 4 //
  /////////////
  // Formulas 18 and 19 in [2].

  logic [3:0] a_y1_qqq, a_y0_qqq, b_y1_qqq, b_y0_qqq;
  caliptra_prim_flop_en #(
    .Width      ( 16 ),
    .ResetValue ( '0 )
  ) u_caliptra_prim_flop_ab_y10_qqq (
    .clk_i  ( clk_i                                    ),
    .rst_ni ( rst_ni                                   ),
    .en_i   ( we_i[2]                                  ),
    .d_i    ( {a_y1,     a_y0,     b_y1,     b_y0}     ),
    .q_o    ( {a_y1_qqq, a_y0_qqq, b_y1_qqq, b_y0_qqq} )
  );

  aes_dom_indep_mul_gf2pn #(
    .NPower   ( 4           ),
    .Pipeline ( PipelineMul )
  ) u_aes_dom_mul_theta_y1 (
    .clk_i  ( clk_i            ),
    .rst_ni ( rst_ni           ),
    .we_i   ( we_i[3]          ),
    .a_x    ( a_y1_qqq         ), // Share a of x
    .a_y    ( a_theta          ), // Share a of y
    .b_x    ( b_y1_qqq         ), // Share b of x
    .b_y    ( b_theta          ), // Share b of y
    .z_0    ( prd_i.prd_4[7:4] ), // Randomness for resharing
    .a_q    ( a_y_inv[3:0]     ), // Share a of q
    .b_q    ( b_y_inv[3:0]     )  // Share b of q
  );

  aes_dom_indep_mul_gf2pn #(
    .NPower   ( 4           ),
    .Pipeline ( PipelineMul )
  ) u_aes_dom_mul_theta_y0 (
    .clk_i  ( clk_i            ),
    .rst_ni ( rst_ni           ),
    .we_i   ( we_i[3]          ),
    .a_x    ( a_theta          ), // Share a of x
    .a_y    ( a_y0_qqq         ), // Share a of y
    .b_x    ( b_theta          ), // Share b of x
    .b_y    ( b_y0_qqq         ), // Share b of y
    .z_0    ( prd_i.prd_4[3:0] ), // Randomness for resharing
    .a_q    ( a_y_inv[7:4]     ), // Share a of q
    .b_q    ( b_y_inv[7:4]     )  // Share b of q
  );

endmodule

// SEC_CM: KEY.MASKING
module aes_sbox_dom
#(
  parameter bit PipelineMul = 1'b1
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              en_i,
  output logic              out_req_o,
  input  logic              out_ack_i,
  input  aes_pkg::ciph_op_e op_i,
  input  logic        [7:0] data_i, // masked, the actual input data is data_i ^ mask_i
  input  logic        [7:0] mask_i, // input mask
  input  logic       [27:0] prd_i,  // pseudo-random data for remasking, in total we need 28 bits
                                    // of PRD per evaluation, but at most 8 bits per cycle
  output logic        [7:0] data_o, // masked, the actual output data is data_o ^ mask_o
  output logic        [7:0] mask_o, // output mask
  output logic       [19:0] prd_o   // PRD for usage in Stages 2 - 4 of other S-Box instances
);

  import aes_reg_pkg::*;
  import aes_pkg::*;
  import aes_sbox_canright_pkg::*;

  logic [7:0] in_data_basis_x, out_data_basis_x;
  logic [7:0] in_mask_basis_x, out_mask_basis_x;
  logic [3:0] we;
  logic [7:0] prd1_d, prd1_q;
  prd_in_t    in_prd;
  prd_out_t   out_prd;

  // Convert data to normal basis X.
  assign in_data_basis_x = (op_i == CIPH_FWD) ? aes_mvm(data_i, A2X)         :
                           (op_i == CIPH_INV) ? aes_mvm(data_i ^ 8'h63, S2X) :
                                                aes_mvm(data_i, A2X);

  // Convert mask to normal basis X.
  // The addition of constant 8'h63 prior to the affine transformation is skipped.
  assign in_mask_basis_x = (op_i == CIPH_FWD) ? aes_mvm(mask_i, A2X) :
                           (op_i == CIPH_INV) ? aes_mvm(mask_i, S2X) :
                                                aes_mvm(mask_i, A2X);

  // Do the inversion in normal basis X.
  aes_dom_inverse_gf2p8 #(
    .PipelineMul ( PipelineMul )
  ) u_aes_dom_inverse_gf2p8 (
    .clk_i   ( clk_i            ),
    .rst_ni  ( rst_ni           ),
    .we_i    ( we               ),
    .a_y     ( in_data_basis_x  ), // input
    .b_y     ( in_mask_basis_x  ), // input
    .prd_i   ( in_prd           ), // input
    .a_y_inv ( out_data_basis_x ), // output
    .b_y_inv ( out_mask_basis_x ), // output
    .prd_o   ( out_prd          )  // output
  );

  // Convert data to basis S or A.
  assign data_o = (op_i == CIPH_FWD) ? (aes_mvm(out_data_basis_x, X2S) ^ 8'h63) :
                  (op_i == CIPH_INV) ? (aes_mvm(out_data_basis_x, X2A))         :
                                       (aes_mvm(out_data_basis_x, X2S) ^ 8'h63);

  // Convert mask to basis S or A.
  // The addition of constant 8'h63 following the affine transformation is skipped.
  assign mask_o = (op_i == CIPH_FWD) ? aes_mvm(out_mask_basis_x, X2S) :
                  (op_i == CIPH_INV) ? aes_mvm(out_mask_basis_x, X2A) :
                                       aes_mvm(out_mask_basis_x, X2S);

  // Counter register
  logic [2:0] count_d, count_q;
  assign count_d = (out_req_o && out_ack_i) ? '0             :
                   out_req_o                ? count_q        :
                   en_i                     ? count_q + 3'd1 : count_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_count
    if (!rst_ni) begin
      count_q <= '0;
    end else begin
      count_q <= count_d;
    end
  end
  assign out_req_o = en_i & count_q == 3'd4;

  // Write enable signals for internal registers
  assign we[0] = en_i & count_q == 3'd0;
  assign we[1] = en_i & count_q == 3'd1;
  assign we[2] = en_i & count_q == 3'd2;
  assign we[3] = en_i & count_q == 3'd3;

  // Buffer and forward PRD for the individual stages. We get 8 bits from the PRNG for usage in the
  // first cycle. Stages 2, 3 and 4 are driven by other S-Box instances.
  assign prd1_d = we[0] ? prd_i[7:0] : prd1_q;
  caliptra_prim_flop #(
    .Width      ( 8  ),
    .ResetValue ( '0 )
  ) u_caliptra_prim_flop_prd1_q (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),
    .d_i    ( prd1_d ),
    .q_o    ( prd1_q )
  );
  assign in_prd = '{prd_1: prd1_d,
                    prd_2: prd_i[11:8],
                    prd_3: prd_i[19:12],
                    prd_4: prd_i[27:20]};
  assign prd_o = {out_prd.prd_3, out_prd.prd_2, out_prd.prd_1};

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES LUT-based SBox

module aes_sbox_lut (
  input  aes_pkg::ciph_op_e op_i,
  input  logic [7:0]        data_i,
  output logic [7:0]        data_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;

  // Define the LUTs
  localparam logic [7:0] SBOX_FWD [256] = '{
    8'h63, 8'h7C, 8'h77, 8'h7B, 8'hF2, 8'h6B, 8'h6F, 8'hC5,
    8'h30, 8'h01, 8'h67, 8'h2B, 8'hFE, 8'hD7, 8'hAB, 8'h76,

    8'hCA, 8'h82, 8'hC9, 8'h7D, 8'hFA, 8'h59, 8'h47, 8'hF0,
    8'hAD, 8'hD4, 8'hA2, 8'hAF, 8'h9C, 8'hA4, 8'h72, 8'hC0,

    8'hB7, 8'hFD, 8'h93, 8'h26, 8'h36, 8'h3F, 8'hF7, 8'hCC,
    8'h34, 8'hA5, 8'hE5, 8'hF1, 8'h71, 8'hD8, 8'h31, 8'h15,

    8'h04, 8'hC7, 8'h23, 8'hC3, 8'h18, 8'h96, 8'h05, 8'h9A,
    8'h07, 8'h12, 8'h80, 8'hE2, 8'hEB, 8'h27, 8'hB2, 8'h75,

    8'h09, 8'h83, 8'h2C, 8'h1A, 8'h1B, 8'h6E, 8'h5A, 8'hA0,
    8'h52, 8'h3B, 8'hD6, 8'hB3, 8'h29, 8'hE3, 8'h2F, 8'h84,

    8'h53, 8'hD1, 8'h00, 8'hED, 8'h20, 8'hFC, 8'hB1, 8'h5B,
    8'h6A, 8'hCB, 8'hBE, 8'h39, 8'h4A, 8'h4C, 8'h58, 8'hCF,

    8'hD0, 8'hEF, 8'hAA, 8'hFB, 8'h43, 8'h4D, 8'h33, 8'h85,
    8'h45, 8'hF9, 8'h02, 8'h7F, 8'h50, 8'h3C, 8'h9F, 8'hA8,

    8'h51, 8'hA3, 8'h40, 8'h8F, 8'h92, 8'h9D, 8'h38, 8'hF5,
    8'hBC, 8'hB6, 8'hDA, 8'h21, 8'h10, 8'hFF, 8'hF3, 8'hD2,

    8'hCD, 8'h0C, 8'h13, 8'hEC, 8'h5F, 8'h97, 8'h44, 8'h17,
    8'hC4, 8'hA7, 8'h7E, 8'h3D, 8'h64, 8'h5D, 8'h19, 8'h73,

    8'h60, 8'h81, 8'h4F, 8'hDC, 8'h22, 8'h2A, 8'h90, 8'h88,
    8'h46, 8'hEE, 8'hB8, 8'h14, 8'hDE, 8'h5E, 8'h0B, 8'hDB,

    8'hE0, 8'h32, 8'h3A, 8'h0A, 8'h49, 8'h06, 8'h24, 8'h5C,
    8'hC2, 8'hD3, 8'hAC, 8'h62, 8'h91, 8'h95, 8'hE4, 8'h79,

    8'hE7, 8'hC8, 8'h37, 8'h6D, 8'h8D, 8'hD5, 8'h4E, 8'hA9,
    8'h6C, 8'h56, 8'hF4, 8'hEA, 8'h65, 8'h7A, 8'hAE, 8'h08,

    8'hBA, 8'h78, 8'h25, 8'h2E, 8'h1C, 8'hA6, 8'hB4, 8'hC6,
    8'hE8, 8'hDD, 8'h74, 8'h1F, 8'h4B, 8'hBD, 8'h8B, 8'h8A,

    8'h70, 8'h3E, 8'hB5, 8'h66, 8'h48, 8'h03, 8'hF6, 8'h0E,
    8'h61, 8'h35, 8'h57, 8'hB9, 8'h86, 8'hC1, 8'h1D, 8'h9E,

    8'hE1, 8'hF8, 8'h98, 8'h11, 8'h69, 8'hD9, 8'h8E, 8'h94,
    8'h9B, 8'h1E, 8'h87, 8'hE9, 8'hCE, 8'h55, 8'h28, 8'hDF,

    8'h8C, 8'hA1, 8'h89, 8'h0D, 8'hBF, 8'hE6, 8'h42, 8'h68,
    8'h41, 8'h99, 8'h2D, 8'h0F, 8'hB0, 8'h54, 8'hBB, 8'h16
  };

  localparam logic [7:0] SBOX_INV [256] = '{
    8'h52, 8'h09, 8'h6a, 8'hd5, 8'h30, 8'h36, 8'ha5, 8'h38,
    8'hbf, 8'h40, 8'ha3, 8'h9e, 8'h81, 8'hf3, 8'hd7, 8'hfb,

    8'h7c, 8'he3, 8'h39, 8'h82, 8'h9b, 8'h2f, 8'hff, 8'h87,
    8'h34, 8'h8e, 8'h43, 8'h44, 8'hc4, 8'hde, 8'he9, 8'hcb,

    8'h54, 8'h7b, 8'h94, 8'h32, 8'ha6, 8'hc2, 8'h23, 8'h3d,
    8'hee, 8'h4c, 8'h95, 8'h0b, 8'h42, 8'hfa, 8'hc3, 8'h4e,

    8'h08, 8'h2e, 8'ha1, 8'h66, 8'h28, 8'hd9, 8'h24, 8'hb2,
    8'h76, 8'h5b, 8'ha2, 8'h49, 8'h6d, 8'h8b, 8'hd1, 8'h25,

    8'h72, 8'hf8, 8'hf6, 8'h64, 8'h86, 8'h68, 8'h98, 8'h16,
    8'hd4, 8'ha4, 8'h5c, 8'hcc, 8'h5d, 8'h65, 8'hb6, 8'h92,

    8'h6c, 8'h70, 8'h48, 8'h50, 8'hfd, 8'hed, 8'hb9, 8'hda,
    8'h5e, 8'h15, 8'h46, 8'h57, 8'ha7, 8'h8d, 8'h9d, 8'h84,

    8'h90, 8'hd8, 8'hab, 8'h00, 8'h8c, 8'hbc, 8'hd3, 8'h0a,
    8'hf7, 8'he4, 8'h58, 8'h05, 8'hb8, 8'hb3, 8'h45, 8'h06,

    8'hd0, 8'h2c, 8'h1e, 8'h8f, 8'hca, 8'h3f, 8'h0f, 8'h02,
    8'hc1, 8'haf, 8'hbd, 8'h03, 8'h01, 8'h13, 8'h8a, 8'h6b,

    8'h3a, 8'h91, 8'h11, 8'h41, 8'h4f, 8'h67, 8'hdc, 8'hea,
    8'h97, 8'hf2, 8'hcf, 8'hce, 8'hf0, 8'hb4, 8'he6, 8'h73,

    8'h96, 8'hac, 8'h74, 8'h22, 8'he7, 8'had, 8'h35, 8'h85,
    8'he2, 8'hf9, 8'h37, 8'he8, 8'h1c, 8'h75, 8'hdf, 8'h6e,

    8'h47, 8'hf1, 8'h1a, 8'h71, 8'h1d, 8'h29, 8'hc5, 8'h89,
    8'h6f, 8'hb7, 8'h62, 8'h0e, 8'haa, 8'h18, 8'hbe, 8'h1b,

    8'hfc, 8'h56, 8'h3e, 8'h4b, 8'hc6, 8'hd2, 8'h79, 8'h20,
    8'h9a, 8'hdb, 8'hc0, 8'hfe, 8'h78, 8'hcd, 8'h5a, 8'hf4,

    8'h1f, 8'hdd, 8'ha8, 8'h33, 8'h88, 8'h07, 8'hc7, 8'h31,
    8'hb1, 8'h12, 8'h10, 8'h59, 8'h27, 8'h80, 8'hec, 8'h5f,

    8'h60, 8'h51, 8'h7f, 8'ha9, 8'h19, 8'hb5, 8'h4a, 8'h0d,
    8'h2d, 8'he5, 8'h7a, 8'h9f, 8'h93, 8'hc9, 8'h9c, 8'hef,

    8'ha0, 8'he0, 8'h3b, 8'h4d, 8'hae, 8'h2a, 8'hf5, 8'hb0,
    8'hc8, 8'heb, 8'hbb, 8'h3c, 8'h83, 8'h53, 8'h99, 8'h61,

    8'h17, 8'h2b, 8'h04, 8'h7e, 8'hba, 8'h77, 8'hd6, 8'h26,
    8'he1, 8'h69, 8'h14, 8'h63, 8'h55, 8'h21, 8'h0c, 8'h7d
  };

  // Drive output
  assign data_o = (op_i == CIPH_FWD) ? SBOX_FWD[data_i] :
                  (op_i == CIPH_INV) ? SBOX_INV[data_i] : SBOX_FWD[data_i];

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES SBox

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_sbox 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter sbox_impl_e SecSBoxImpl = SBoxImplLut
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,
  input  logic                     en_i,
  output logic                     out_req_o,
  input  logic                     out_ack_i,
  input  ciph_op_e                 op_i,
  input  logic               [7:0] data_i,
  input  logic               [7:0] mask_i,
  input  logic [WidthPRDSBox+19:0] prd_i,
  output logic               [7:0] data_o,
  output logic               [7:0] mask_o,
  output logic              [19:0] prd_o
);

  // Create a lint error to reduce the risk of accidentally using a less secure SBox
  // implementation.
  `CALIPTRA_ASSERT_STATIC_LINT_ERROR(AesSBoxSecSBoxImplNonDefault, SecSBoxImpl == SBoxImplDom)

  localparam bit SBoxMasked = (SecSBoxImpl == SBoxImplCanrightMasked ||
                               SecSBoxImpl == SBoxImplCanrightMaskedNoreuse ||
                               SecSBoxImpl == SBoxImplDom) ? 1'b1 : 1'b0;

  localparam bit SBoxSingleCycle = (SecSBoxImpl == SBoxImplDom) ? 1'b0 : 1'b1;

  if (!SBoxMasked) begin : gen_sbox_unmasked
    // Tie off unused inputs.
    logic                     unused_clk;
    logic                     unused_rst;
    logic               [7:0] unused_mask;
    logic [WidthPRDSBox+19:0] unused_prd;
    assign unused_clk  = clk_i;
    assign unused_rst  = rst_ni;
    assign unused_mask = mask_i;
    assign unused_prd  = prd_i;

    if (SecSBoxImpl == SBoxImplCanright) begin : gen_sbox_canright
      aes_sbox_canright u_aes_sbox (
        .op_i   ( op_i   ),
        .data_i ( data_i ),
        .data_o ( data_o )
      );

    end else begin : gen_sbox_lut // SecSBoxImpl == SBoxImplLut
      aes_sbox_lut u_aes_sbox (
        .op_i   ( op_i   ),
        .data_i ( data_i ),
        .data_o ( data_o )
      );
    end

    assign mask_o = '0;
    assign prd_o  = '0;

  end else begin : gen_sbox_masked

    // SEC_CM: KEY.MASKING
    if (SecSBoxImpl == SBoxImplDom) begin : gen_sbox_dom

      aes_sbox_dom u_aes_sbox (
        .clk_i      ( clk_i       ),
        .rst_ni     ( rst_ni      ),
        .en_i       ( en_i        ),
        .out_req_o  ( out_req_o   ),
        .out_ack_i  ( out_ack_i   ),
        .op_i       ( op_i        ),
        .data_i     ( data_i      ),
        .mask_i     ( mask_i      ),
        .prd_i      ( prd_i[27:0] ),
        .data_o     ( data_o      ),
        .mask_o     ( mask_o      ),
        .prd_o      ( prd_o       )
      );

      `CALIPTRA_ASSERT_INIT(AesWidthPRDSBox, WidthPRDSBox == 8)

    end else if (SecSBoxImpl == SBoxImplCanrightMaskedNoreuse) begin :
        gen_sbox_canright_masked_noreuse
      // Tie off unused inputs.
      logic        unused_clk;
      logic        unused_rst;
      logic [19:0] unused_prd;
      assign unused_clk = clk_i;
      assign unused_rst = rst_ni;
      assign unused_prd = prd_i[WidthPRDSBox+19:WidthPRDSBox];

      aes_sbox_canright_masked_noreuse u_aes_sbox (
        .op_i   ( op_i        ),
        .data_i ( data_i      ),
        .mask_i ( mask_i      ),
        .prd_i  ( prd_i[17:0] ),
        .data_o ( data_o      ),
        .mask_o ( mask_o      )
      );

      assign prd_o = '0;

      `CALIPTRA_ASSERT_INIT(AesWidthPRDSBox, WidthPRDSBox == 18)

    end else begin : gen_sbox_canright_masked // SecSBoxImpl == SBoxImplCanrightMasked
      // Tie off unused inputs.
      logic        unused_clk;
      logic        unused_rst;
      logic [19:0] unused_prd;
      assign unused_clk = clk_i;
      assign unused_rst = rst_ni;
      assign unused_prd = prd_i[WidthPRDSBox+19:WidthPRDSBox];

      aes_sbox_canright_masked u_aes_sbox (
        .op_i   ( op_i       ),
        .data_i ( data_i     ),
        .mask_i ( mask_i     ),
        .prd_i  ( prd_i[7:0] ),
        .data_o ( data_o     ),
        .mask_o ( mask_o     )
      );

      assign prd_o = '0;

      `CALIPTRA_ASSERT_INIT(AesWidthPRDSBox, WidthPRDSBox == 8)
    end
  end

  if (SBoxSingleCycle) begin : gen_req_singlecycle
    // Tie off unused inputs.
    logic unused_out_ack;
    assign unused_out_ack = out_ack_i;

    // Signal that we have valid output right away.
    assign out_req_o = en_i;
  end

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES mux selector buffer and checker
//
// When using sparse encodings for mux selector signals, this module can be used to:
// 1. Prevent aggressive synthesis optimizations on the selector signal, and
// 2. to check that the selector signal is valid, i.e., doesn't take on invalid values.
// Whenever the selector signal takes on an invalid value, an error is signaled.

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module aes_sel_buf_chk #(
  parameter int Num      = 2,
  parameter int Width    = 1,
  parameter bit EnSecBuf = 1'b0
) (
  input  logic             clk_i,  // Used for assertions only.
  input  logic             rst_ni, // Used for assertions only.
  input  logic [Width-1:0] sel_i,
  output logic [Width-1:0] sel_o,
  output logic             err_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;

  // Tie off unused inputs.
  logic unused_clk;
  logic unused_rst;
  assign unused_clk = clk_i;
  assign unused_rst = rst_ni;

  ////////////
  // Buffer //
  ////////////

  if (EnSecBuf) begin : gen_sec_buf
    caliptra_prim_sec_anchor_buf #(
      .Width ( Width )
    ) u_caliptra_prim_buf_sel_i (
      .in_i  ( sel_i ),
      .out_o ( sel_o )
    );
  end else begin : gen_buf
    caliptra_prim_buf  #(
      .Width ( Width )
    ) u_caliptra_prim_buf_sel_i (
      .in_i  ( sel_i ),
      .out_o ( sel_o )
    );
  end

  /////////////
  // Checker //
  /////////////

  if (Num == 2) begin : gen_mux2_sel_chk
    // Cast to generic type.
    mux2_sel_e sel_chk;
    assign sel_chk = mux2_sel_e'(sel_o);

    // Actual checker
    always_comb begin : mux2_sel_chk
      unique case (sel_chk)
        MUX2_SEL_0,
        MUX2_SEL_1: err_o = 1'b0;
        default:    err_o = 1'b1;
      endcase
    end

    // Assertion
    `CALIPTRA_ASSERT(AesMux2SelValid, !err_o |-> sel_chk inside {
        MUX2_SEL_0,
        MUX2_SEL_1
        })

  end else if (Num == 3) begin : gen_mux3_sel_chk
    // Cast to generic type.
    mux3_sel_e sel_chk;
    assign sel_chk = mux3_sel_e'(sel_o);

    // Actual checker
    always_comb begin : mux3_sel_chk
      unique case (sel_chk)
        MUX3_SEL_0,
        MUX3_SEL_1,
        MUX3_SEL_2: err_o = 1'b0;
        default:    err_o = 1'b1;
      endcase
    end

    // Assertion
    `CALIPTRA_ASSERT(AesMux3SelValid, !err_o |-> sel_chk inside {
        MUX3_SEL_0,
        MUX3_SEL_1,
        MUX3_SEL_2
        })

  end else if (Num == 4) begin : gen_mux4_sel_chk
    // Cast to generic type.
    mux4_sel_e sel_chk;
    assign sel_chk = mux4_sel_e'(sel_o);

    // Actual checker
    always_comb begin : mux4_sel_chk
      unique case (sel_chk)
        MUX4_SEL_0,
        MUX4_SEL_1,
        MUX4_SEL_2,
        MUX4_SEL_3: err_o = 1'b0;
        default:    err_o = 1'b1;
      endcase
    end

    // Assertion
    `CALIPTRA_ASSERT(AesMux4SelValid, !err_o |-> sel_chk inside {
        MUX4_SEL_0,
        MUX4_SEL_1,
        MUX4_SEL_2,
        MUX4_SEL_3
        })

  end else if (Num == 6) begin : gen_mux6_sel_chk
    // Cast to generic type.
    mux6_sel_e sel_chk;
    assign sel_chk = mux6_sel_e'(sel_o);

    // Actual checker
    always_comb begin : mux6_sel_chk
      unique case (sel_chk)
        MUX6_SEL_0,
        MUX6_SEL_1,
        MUX6_SEL_2,
        MUX6_SEL_3,
        MUX6_SEL_4,
        MUX6_SEL_5: err_o = 1'b0;
        default:    err_o = 1'b1;
      endcase
    end

    // Assertion
    `CALIPTRA_ASSERT(AesMux6SelValid, !err_o |-> sel_chk inside {
        MUX6_SEL_0,
        MUX6_SEL_1,
        MUX6_SEL_2,
        MUX6_SEL_3,
        MUX6_SEL_4,
        MUX6_SEL_5
        })

  end else begin : gen_width_unsupported
    // Selected width not supported, signal error.
    assign err_o = 1'b1;
  end

  ////////////////
  // Assertions //
  ////////////////

  // We only have generic sparse encodings defined for certain mux input numbers (see aes_pkg.sv).
  `CALIPTRA_ASSERT_INIT(AesSelBufChkNum, Num inside {2, 3, 4, 6})

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES ShiftRows

module aes_shift_rows (
  input  aes_pkg::ciph_op_e    op_i,
  input  logic [3:0][3:0][7:0] data_i,
  output logic [3:0][3:0][7:0] data_o
);

  import aes_reg_pkg::*;
  import aes_pkg::*;

  // Row 0 is left untouched
  assign data_o[0] = data_i[0];

  // Row 2 does not depend on op_i
  assign data_o[2] = aes_circ_byte_shift(data_i[2], 2'h2);

  // Row 1
  assign data_o[1] = (op_i == CIPH_FWD) ? aes_circ_byte_shift(data_i[1], 2'h3) :
                     (op_i == CIPH_INV) ? aes_circ_byte_shift(data_i[1], 2'h1) :
                                          aes_circ_byte_shift(data_i[1], 2'h3);

  // Row 3
  assign data_o[3] = (op_i == CIPH_FWD) ? aes_circ_byte_shift(data_i[3], 2'h1) :
                     (op_i == CIPH_INV) ? aes_circ_byte_shift(data_i[3], 2'h3) :
                                          aes_circ_byte_shift(data_i[3], 2'h1);

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES SubBytes

module aes_sub_bytes 
  import aes_reg_pkg::*;
  import aes_pkg::*;
#(
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,
  input  sp2v_e                             en_i,
  output sp2v_e                             out_req_o,
  input  sp2v_e                             out_ack_i,
  input  ciph_op_e                          op_i,
  input  logic              [3:0][3:0][7:0] data_i,
  input  logic              [3:0][3:0][7:0] mask_i,
  input  logic [3:0][3:0][WidthPRDSBox-1:0] prd_i,
  output logic              [3:0][3:0][7:0] data_o,
  output logic              [3:0][3:0][7:0] mask_o,
  output logic                              err_o
);

  sp2v_e           en;
  logic            en_err;
  logic [3:0][3:0] out_req;
  sp2v_e           out_ack;
  logic            out_ack_err;

  // Every DOM S-Box instance consumes 28 bits of randomness but itself produces 20 bits for use in
  // another S-Box instance. For other S-Box implementations, only the bits corresponding to prd_i
  // are used. Other bits are ignored and tied to 0.
  logic [3:0][3:0][WidthPRDSBox+19:0] in_prd;
  logic [3:0][3:0]             [19:0] out_prd;

  // SEC_CM: CTRL.SPARSE
  // Check sparsely encoded signals.
  logic [Sp2VWidth-1:0] en_raw;
  aes_sel_buf_chk #(
    .Num      ( Sp2VNum   ),
    .Width    ( Sp2VWidth ),
    .EnSecBuf ( 1'b1      )
  ) u_aes_sb_en_buf_chk (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),
    .sel_i  ( en_i   ),
    .sel_o  ( en_raw ),
    .err_o  ( en_err )
  );
  assign en = sp2v_e'(en_raw);

  logic [Sp2VWidth-1:0] out_ack_raw;
  aes_sel_buf_chk #(
    .Num      ( Sp2VNum   ),
    .Width    ( Sp2VWidth ),
    .EnSecBuf ( 1'b1      )
  ) u_aes_sb_out_ack_buf_chk (
    .clk_i  ( clk_i       ),
    .rst_ni ( rst_ni      ),
    .sel_i  ( out_ack_i   ),
    .sel_o  ( out_ack_raw ),
    .err_o  ( out_ack_err )
  );
  assign out_ack = sp2v_e'(out_ack_raw);

  // Individually substitute bytes.
  for (genvar j = 0; j < 4; j++) begin : gen_sbox_j
    for (genvar i = 0; i < 4; i++) begin : gen_sbox_i

      // Rotate the randomness produced by the S-Boxes over the columns but not across rows as
      // MixColumns will operate across rows. The LSBs are taken from the masking PRNG (prd_i)
      // whereas the MSBs are produced by the other S-Box instances.
      assign in_prd[i][j] = {out_prd[i][aes_rot_int(j,4)], prd_i[i][j]};

      aes_sbox #(
        .SecSBoxImpl ( SecSBoxImpl )
      ) u_aes_sbox_ij (
        .clk_i     ( clk_i                ),
        .rst_ni    ( rst_ni               ),
        .en_i      ( en == SP2V_HIGH      ),
        .out_req_o ( out_req[i][j]        ),
        .out_ack_i ( out_ack == SP2V_HIGH ),
        .op_i      ( op_i                 ),
        .data_i    ( data_i[i][j]         ),
        .mask_i    ( mask_i[i][j]         ),
        .prd_i     ( in_prd[i][j]         ),
        .data_o    ( data_o[i][j]         ),
        .mask_o    ( mask_o[i][j]         ),
        .prd_o     ( out_prd[i][j]        )
      );
    end
  end

  // Collect REQ signals.
  assign out_req_o = &out_req ? SP2V_HIGH : SP2V_LOW;

  // Collect encoding errors.
  assign err_o = en_err | out_ack_err;

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This file is auto-generated.
// Used parser: Verible

`ifndef PRIM_DEFAULT_IMPL
  `define CALIPTRA_PRIM_DEFAULT_IMPL caliptra_prim_pkg::ImplGeneric
`endif

// This is to prevent AscentLint warnings in the generated
// abstract prim wrapper. These warnings occur due to the .*
// use. TODO: we may want to move these inline waivers
// into a separate, generated waiver file for consistency.
//ri lint_check_off OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
module caliptra_prim_buf

#(
parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);
  parameter caliptra_prim_pkg::impl_e Impl = `CALIPTRA_PRIM_DEFAULT_IMPL;

if (Impl == caliptra_prim_pkg::ImplXilinx) begin : gen_xilinx
    caliptra_prim_xilinx_buf #(
      .Width(Width)
    ) u_impl_xilinx (
      .*
    );
end else begin : gen_generic
    caliptra_prim_generic_buf #(
      .Width(Width)
    ) u_impl_generic (
      .*
    );
end

endmodule
//ri lint_check_on OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_sparse_fsm_flop
  import caliptra_prim_sparse_fsm_pkg::*;
#(
  parameter int               Width      = 1,
  parameter type              StateEnumT = state_t,
  parameter logic [Width-1:0] ResetValue = '0,
  // This should only be disabled in special circumstances, for example
  // in non-comportable IPs where an error does not trigger an alert.
  parameter bit               EnableAlertTriggerSVA = 1
`ifdef CALIPTRA_SIMULATION
  ,
  // In case this parameter is set to a non-empty string, the
  // caliptra_prim_sparse_fsm_flop_if will also force the signal with this name
  // in the parent module that instantiates caliptra_prim_sparse_fsm_flop.
  parameter string            CustomForceName = ""
`endif
) (
  input             clk_i,
  input             rst_ni,
  input  StateEnumT state_i,
  output StateEnumT state_o
);

  logic unused_err_o;

  logic [Width-1:0] state_raw;
  caliptra_prim_flop #(
    .Width(Width),
    .ResetValue(ResetValue)
  ) u_state_flop (
    .clk_i,
    .rst_ni,
    .d_i(state_i),
    .q_o(state_raw)
  );
  assign state_o = StateEnumT'(state_raw);

  `ifdef CALIPTRA_INC_ASSERT
  assign unused_err_o = is_undefined_state(state_o);

  function automatic logic is_undefined_state(StateEnumT sig);
    // This is written with a vector in order to make it amenable to x-prop analysis.
    logic is_defined = 1'b0;
    for (int i = 0, StateEnumT t = t.first(); i < t.num(); i += 1, t = t.next()) begin
      is_defined |= (sig === t);
    end
    return ~is_defined;
  endfunction

  `else
    assign unused_err_o = 1'b0;
  `endif

  // If CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT is declared, the unused_assert_connected signal will
  // be set to 1 and the below check will pass.
  // If the assertion is not declared however, the statement below will fail.
  `ifdef CALIPTRA_INC_ASSERT
  logic unused_assert_connected;

  `CALIPTRA_ASSERT_INIT_NET(AssertConnected_A, unused_assert_connected === 1'b1 || !EnableAlertTriggerSVA)
  `endif

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This file is auto-generated.
// Used parser: Fallback (regex)

`ifndef PRIM_DEFAULT_IMPL
  `define CALIPTRA_PRIM_DEFAULT_IMPL caliptra_prim_pkg::ImplGeneric
`endif

// This is to prevent AscentLint warnings in the generated
// abstract prim wrapper. These warnings occur due to the .*
// use. TODO: we may want to move these inline waivers
// into a separate, generated waiver file for consistency.
//ri lint_check_off OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
module caliptra_prim_flop

#(

  parameter int               Width      = 1,
  parameter logic [Width-1:0] ResetValue = 0

) (
  input                    clk_i,
  input                    rst_ni,
  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);
  parameter caliptra_prim_pkg::impl_e Impl = `CALIPTRA_PRIM_DEFAULT_IMPL;

if (Impl == caliptra_prim_pkg::ImplXilinx) begin : gen_xilinx
    caliptra_prim_xilinx_flop #(
      .ResetValue(ResetValue),
      .Width(Width)
    ) u_impl_xilinx (
      .*
    );
end else begin : gen_generic
    caliptra_prim_generic_flop #(
      .ResetValue(ResetValue),
      .Width(Width)
    ) u_impl_generic (
      .*
    );
end

endmodule
//ri lint_check_on OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This file is auto-generated.
// Used parser: Fallback (regex)

`ifndef PRIM_DEFAULT_IMPL
  `define CALIPTRA_PRIM_DEFAULT_IMPL caliptra_prim_pkg::ImplGeneric
`endif

// This is to prevent AscentLint warnings in the generated
// abstract prim wrapper. These warnings occur due to the .*
// use. TODO: we may want to move these inline waivers
// into a separate, generated waiver file for consistency.
//ri lint_check_off OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
module caliptra_prim_flop_en

#(

  parameter int               Width      = 1,
  parameter bit               EnSecBuf   = 0,
  parameter logic [Width-1:0] ResetValue = 0

) (
  input                    clk_i,
  input                    rst_ni,
  input                    en_i,
  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);
  parameter caliptra_prim_pkg::impl_e Impl = `CALIPTRA_PRIM_DEFAULT_IMPL;

if (Impl == caliptra_prim_pkg::ImplXilinx) begin : gen_xilinx
    caliptra_prim_xilinx_flop_en #(
      .EnSecBuf(EnSecBuf),
      .ResetValue(ResetValue),
      .Width(Width)
    ) u_impl_xilinx (
      .*
    );
end else begin : gen_generic
    caliptra_prim_generic_flop_en #(
      .EnSecBuf(EnSecBuf),
      .ResetValue(ResetValue),
      .Width(Width)
    ) u_impl_generic (
      .*
    );
end

endmodule
//ri lint_check_on OUTPUT_NOT_DRIVEN INPUT_NOT_READ HIER_BRANCH_NOT_READ
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// This module implements different LFSR types:
//
// 0) Galois XOR type LFSR ([1], internal XOR gates, very fast).
//    Parameterizable width from 4 to 64 bits.
//    Coefficients obtained from [2].
//
// 1) Fibonacci XNOR type LFSR, parameterizable from 3 to 168 bits.
//    Coefficients obtained from [3].
//
// All flavors have an additional entropy input and lockup protection, which
// reseeds the state once it has accidentally fallen into the all-zero (XOR) or
// all-one (XNOR) state. Further, an external seed can be loaded into the LFSR
// state at runtime. If that seed is all-zero (XOR case) or all-one (XNOR case),
// the state will be reseeded in the next cycle using the lockup protection mechanism.
// Note that the external seed input takes precedence over internal state updates.
//
// All polynomials up to 34 bit in length have been verified in simulation.
//
// Refs: [1] https://en.wikipedia.org/wiki/Linear-feedback_shift_register
//       [2] https://users.ece.cmu.edu/~koopman/lfsr/
//       [3] https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_lfsr #(
  // Lfsr Type, can be FIB_XNOR or GAL_XOR
  parameter                    LfsrType     = "GAL_XOR",
  // Lfsr width
  parameter int unsigned       LfsrDw       = 32,
  // Derived parameter, do not override
  localparam int unsigned      LfsrIdxDw    = $clog2(LfsrDw),
  // Width of the entropy input to be XOR'd into state (lfsr_q[EntropyDw-1:0])
  parameter int unsigned       EntropyDw    =  8,
  // Width of output tap (from lfsr_q[StateOutDw-1:0])
  parameter int unsigned       StateOutDw   =  8,
  // Lfsr reset state, must be nonzero!
  parameter logic [LfsrDw-1:0] DefaultSeed  = LfsrDw'(1),
  // Custom polynomial coeffs
  parameter logic [LfsrDw-1:0] CustomCoeffs = '0,
  // If StatePermEn is set to 1, the custom permutation specified via StatePerm is applied to the
  // state output, in order to break linear shifting patterns of the LFSR. Note that this
  // permutation represents a way of customizing the LFSR via a random netlist constant. This is
  // different from the NonLinearOut feature below which just transforms the output non-linearly
  // with a fixed function. In most cases, designers should consider enabling StatePermEn as it
  // comes basically "for free" in terms of area and timing impact. NonLinearOut on the other hand
  // has area and timing implications and designers should consider whether the use of that feature
  // is justified.
  parameter bit                StatePermEn  = 1'b0,
  parameter logic [LfsrDw-1:0][LfsrIdxDw-1:0] StatePerm = '0,
  // Enable this for DV, disable this for long LFSRs in FPV
  parameter bit                MaxLenSVA    = 1'b1,
  // Can be disabled in cases where seed and entropy
  // inputs are unused in order to not distort coverage
  // (the SVA will be unreachable in such cases)
  parameter bit                LockupSVA    = 1'b1,
  parameter bit                ExtSeedSVA   = 1'b1,
  // Introduce non-linearity to lfsr output. Note, unlike StatePermEn, this feature is not "for
  // free". Please double check that this feature is indeed required. Also note that this feature
  // is only available for LFSRs that have a power-of-two width greater or equal 16bit.
  parameter bit                NonLinearOut = 1'b0
) (
  input                         clk_i,
  input                         rst_ni,
  input                         seed_en_i, // load external seed into the state (takes precedence)
  input        [LfsrDw-1:0]     seed_i,    // external seed input
  input                         lfsr_en_i, // enables the LFSR
  input        [EntropyDw-1:0]  entropy_i, // additional entropy to be XOR'ed into the state
  output logic [StateOutDw-1:0] state_o    // (partial) LFSR state output
);

  // automatically generated with util/design/get-lfsr-coeffs.py script
  localparam int unsigned GAL_XOR_LUT_OFF = 4;
  localparam logic [63:0] GAL_XOR_COEFFS [61] =
    '{ 64'h9,
       64'h12,
       64'h21,
       64'h41,
       64'h8E,
       64'h108,
       64'h204,
       64'h402,
       64'h829,
       64'h100D,
       64'h2015,
       64'h4001,
       64'h8016,
       64'h10004,
       64'h20013,
       64'h40013,
       64'h80004,
       64'h100002,
       64'h200001,
       64'h400010,
       64'h80000D,
       64'h1000004,
       64'h2000023,
       64'h4000013,
       64'h8000004,
       64'h10000002,
       64'h20000029,
       64'h40000004,
       64'h80000057,
       64'h100000029,
       64'h200000073,
       64'h400000002,
       64'h80000003B,
       64'h100000001F,
       64'h2000000031,
       64'h4000000008,
       64'h800000001C,
       64'h10000000004,
       64'h2000000001F,
       64'h4000000002C,
       64'h80000000032,
       64'h10000000000D,
       64'h200000000097,
       64'h400000000010,
       64'h80000000005B,
       64'h1000000000038,
       64'h200000000000E,
       64'h4000000000025,
       64'h8000000000004,
       64'h10000000000023,
       64'h2000000000003E,
       64'h40000000000023,
       64'h8000000000004A,
       64'h100000000000016,
       64'h200000000000031,
       64'h40000000000003D,
       64'h800000000000001,
       64'h1000000000000013,
       64'h2000000000000034,
       64'h4000000000000001,
       64'h800000000000000D };

  // automatically generated with get-lfsr-coeffs.py script
  localparam int unsigned FIB_XNOR_LUT_OFF = 3;
  localparam logic [167:0] FIB_XNOR_COEFFS [166] =
    '{ 168'h6,
       168'hC,
       168'h14,
       168'h30,
       168'h60,
       168'hB8,
       168'h110,
       168'h240,
       168'h500,
       168'h829,
       168'h100D,
       168'h2015,
       168'h6000,
       168'hD008,
       168'h12000,
       168'h20400,
       168'h40023,
       168'h90000,
       168'h140000,
       168'h300000,
       168'h420000,
       168'hE10000,
       168'h1200000,
       168'h2000023,
       168'h4000013,
       168'h9000000,
       168'h14000000,
       168'h20000029,
       168'h48000000,
       168'h80200003,
       168'h100080000,
       168'h204000003,
       168'h500000000,
       168'h801000000,
       168'h100000001F,
       168'h2000000031,
       168'h4400000000,
       168'hA000140000,
       168'h12000000000,
       168'h300000C0000,
       168'h63000000000,
       168'hC0000030000,
       168'h1B0000000000,
       168'h300003000000,
       168'h420000000000,
       168'hC00000180000,
       168'h1008000000000,
       168'h3000000C00000,
       168'h6000C00000000,
       168'h9000000000000,
       168'h18003000000000,
       168'h30000000030000,
       168'h40000040000000,
       168'hC0000600000000,
       168'h102000000000000,
       168'h200004000000000,
       168'h600003000000000,
       168'hC00000000000000,
       168'h1800300000000000,
       168'h3000000000000030,
       168'h6000000000000000,
       168'hD800000000000000,
       168'h10000400000000000,
       168'h30180000000000000,
       168'h60300000000000000,
       168'h80400000000000000,
       168'h140000028000000000,
       168'h300060000000000000,
       168'h410000000000000000,
       168'h820000000001040000,
       168'h1000000800000000000,
       168'h3000600000000000000,
       168'h6018000000000000000,
       168'hC000000018000000000,
       168'h18000000600000000000,
       168'h30000600000000000000,
       168'h40200000000000000000,
       168'hC0000000060000000000,
       168'h110000000000000000000,
       168'h240000000480000000000,
       168'h600000000003000000000,
       168'h800400000000000000000,
       168'h1800000300000000000000,
       168'h3003000000000000000000,
       168'h4002000000000000000000,
       168'hC000000000000000018000,
       168'h10000000004000000000000,
       168'h30000C00000000000000000,
       168'h600000000000000000000C0,
       168'hC00C0000000000000000000,
       168'h140000000000000000000000,
       168'h200001000000000000000000,
       168'h400800000000000000000000,
       168'hA00000000001400000000000,
       168'h1040000000000000000000000,
       168'h2004000000000000000000000,
       168'h5000000000028000000000000,
       168'h8000000004000000000000000,
       168'h18600000000000000000000000,
       168'h30000000000000000C00000000,
       168'h40200000000000000000000000,
       168'hC0300000000000000000000000,
       168'h100010000000000000000000000,
       168'h200040000000000000000000000,
       168'h5000000000000000A0000000000,
       168'h800000010000000000000000000,
       168'h1860000000000000000000000000,
       168'h3003000000000000000000000000,
       168'h4010000000000000000000000000,
       168'hA000000000140000000000000000,
       168'h10080000000000000000000000000,
       168'h30000000000000000000180000000,
       168'h60018000000000000000000000000,
       168'hC0000000000000000300000000000,
       168'h140005000000000000000000000000,
       168'h200000001000000000000000000000,
       168'h404000000000000000000000000000,
       168'h810000000000000000000000000102,
       168'h1000040000000000000000000000000,
       168'h3000000000000006000000000000000,
       168'h5000000000000000000000000000000,
       168'h8000000004000000000000000000000,
       168'h18000000000000000000000000030000,
       168'h30000000030000000000000000000000,
       168'h60000000000000000000000000000000,
       168'hA0000014000000000000000000000000,
       168'h108000000000000000000000000000000,
       168'h240000000000000000000000000000000,
       168'h600000000000C00000000000000000000,
       168'h800000040000000000000000000000000,
       168'h1800000000000300000000000000000000,
       168'h2000000000000010000000000000000000,
       168'h4008000000000000000000000000000000,
       168'hC000000000000000000000000000000600,
       168'h10000080000000000000000000000000000,
       168'h30600000000000000000000000000000000,
       168'h4A400000000000000000000000000000000,
       168'h80000004000000000000000000000000000,
       168'h180000003000000000000000000000000000,
       168'h200001000000000000000000000000000000,
       168'h600006000000000000000000000000000000,
       168'hC00000000000000006000000000000000000,
       168'h1000000000000100000000000000000000000,
       168'h3000000000000006000000000000000000000,
       168'h6000000003000000000000000000000000000,
       168'h8000001000000000000000000000000000000,
       168'h1800000000000000000000000000C000000000,
       168'h20000000000001000000000000000000000000,
       168'h48000000000000000000000000000000000000,
       168'hC0000000000000006000000000000000000000,
       168'h180000000000000000000000000000000000000,
       168'h280000000000000000000000000000005000000,
       168'h60000000C000000000000000000000000000000,
       168'hC00000000000000000000000000018000000000,
       168'h1800000600000000000000000000000000000000,
       168'h3000000C00000000000000000000000000000000,
       168'h4000000080000000000000000000000000000000,
       168'hC000300000000000000000000000000000000000,
       168'h10000400000000000000000000000000000000000,
       168'h30000000000000000000006000000000000000000,
       168'h600000000000000C0000000000000000000000000,
       168'hC0060000000000000000000000000000000000000,
       168'h180000006000000000000000000000000000000000,
       168'h3000000000C0000000000000000000000000000000,
       168'h410000000000000000000000000000000000000000,
       168'hA00140000000000000000000000000000000000000 };

  logic lockup;
  logic [LfsrDw-1:0] lfsr_d, lfsr_q;
  logic [LfsrDw-1:0] next_lfsr_state, coeffs;

  // Enable the randomization of DefaultSeed using DefaultSeedLocal in DV simulations.
  `ifdef CALIPTRA_SIMULATION
  `ifdef VERILATOR
      localparam logic [LfsrDw-1:0] DefaultSeedLocal = DefaultSeed;

  `else
    logic [LfsrDw-1:0] DefaultSeedLocal;
    logic caliptra_prim_lfsr_use_default_seed;

    initial begin : p_randomize_default_seed
      if (!$value$plusargs("caliptra_prim_lfsr_use_default_seed=%0d", caliptra_prim_lfsr_use_default_seed)) begin
        // 30% of the time, use the DefaultSeed parameter; 70% of the time, randomize it.
        `CALIPTRA_ASSERT_I(UseDefaultSeedRandomizeCheck_A, std::randomize(caliptra_prim_lfsr_use_default_seed) with {
                                                  caliptra_prim_lfsr_use_default_seed dist {0:/7, 1:/3};})
      end
      if (caliptra_prim_lfsr_use_default_seed) begin
        DefaultSeedLocal = DefaultSeed;
      end else begin
        // Randomize the DefaultSeedLocal ensuring its not all 0s or all 1s.
        `CALIPTRA_ASSERT_I(DefaultSeedLocalRandomizeCheck_A, std::randomize(DefaultSeedLocal) with {
                                                    !(DefaultSeedLocal inside {'0, '1});})
      end
      $display("%m: DefaultSeed = 0x%0h, DefaultSeedLocal = 0x%0h", DefaultSeed, DefaultSeedLocal);
    end
  `endif  // ifdef VERILATOR

  `else
    localparam logic [LfsrDw-1:0] DefaultSeedLocal = DefaultSeed;

  `endif  // ifdef CALIPTRA_SIMULATION

  ////////////////
  // Galois XOR //
  ////////////////
  if (64'(LfsrType) == 64'("GAL_XOR")) begin : gen_gal_xor

    // if custom polynomial is provided
    if (CustomCoeffs > 0) begin : gen_custom
      assign coeffs = CustomCoeffs[LfsrDw-1:0];
    end else begin : gen_lut
      assign coeffs = GAL_XOR_COEFFS[LfsrDw-GAL_XOR_LUT_OFF][LfsrDw-1:0];
      // check that the most significant bit of polynomial is 1
      `CALIPTRA_ASSERT_INIT(MinLfsrWidth_A, LfsrDw >= $low(GAL_XOR_COEFFS)+GAL_XOR_LUT_OFF)
      `CALIPTRA_ASSERT_INIT(MaxLfsrWidth_A, LfsrDw <= $high(GAL_XOR_COEFFS)+GAL_XOR_LUT_OFF)
    end

    // calculate next state using internal XOR feedback and entropy input
    assign next_lfsr_state = LfsrDw'(entropy_i) ^ ({LfsrDw{lfsr_q[0]}} & coeffs) ^ (lfsr_q >> 1);

    // lockup condition is all-zero
    assign lockup = ~(|lfsr_q);

    // check that seed is not all-zero
    `CALIPTRA_ASSERT_INIT(DefaultSeedNzCheck_A, |DefaultSeedLocal)


  ////////////////////
  // Fibonacci XNOR //
  ////////////////////
  end else if (64'(LfsrType) == "FIB_XNOR") begin : gen_fib_xnor

    // if custom polynomial is provided
    if (CustomCoeffs > 0) begin : gen_custom
      assign coeffs = CustomCoeffs[LfsrDw-1:0];
    end else begin : gen_lut
      assign coeffs = FIB_XNOR_COEFFS[LfsrDw-FIB_XNOR_LUT_OFF][LfsrDw-1:0];
      // check that the most significant bit of polynomial is 1
      `CALIPTRA_ASSERT_INIT(MinLfsrWidth_A, LfsrDw >= $low(FIB_XNOR_COEFFS)+FIB_XNOR_LUT_OFF)
      `CALIPTRA_ASSERT_INIT(MaxLfsrWidth_A, LfsrDw <= $high(FIB_XNOR_COEFFS)+FIB_XNOR_LUT_OFF)
    end

    // calculate next state using external XNOR feedback and entropy input
    assign next_lfsr_state = LfsrDw'(entropy_i) ^ {lfsr_q[LfsrDw-2:0], ~(^(lfsr_q & coeffs))};

    // lockup condition is all-ones
    assign lockup = &lfsr_q;

    // check that seed is not all-ones
    `CALIPTRA_ASSERT_INIT(DefaultSeedNzCheck_A, !(&DefaultSeedLocal))


  /////////////
  // Unknown //
  /////////////
  end else begin : gen_unknown_type
    assign coeffs = '0;
    assign next_lfsr_state = '0;
    assign lockup = 1'b0;
    `CALIPTRA_ASSERT_INIT(UnknownLfsrType_A, 0)
  end


  //////////////////
  // Shared logic //
  //////////////////

  assign lfsr_d = (seed_en_i)           ? seed_i          :
                  (lfsr_en_i && lockup) ? DefaultSeedLocal     :
                  (lfsr_en_i)           ? next_lfsr_state :
                                          lfsr_q;

  logic [LfsrDw-1:0] sbox_out;
  if (NonLinearOut) begin : gen_out_non_linear
    // The "aligned" permutation ensures that adjacent bits do not go into the same SBox. It is
    // different from the state permutation that can be specified via the StatePerm parameter. The
    // permutation taps out 4 SBox input bits at regular stride intervals. E.g., for a 16bit
    // vector, the input assignment looks as follows:
    //
    // SBox0: 0,  4,  8, 12
    // SBox1: 1,  5,  9, 13
    // SBox2: 2,  6, 10, 14
    // SBox3: 3,  7, 11, 15
    //
    // Note that this permutation can be produced by filling the input vector into matrix columns
    // and reading out the SBox inputs as matrix rows.
    localparam int NumSboxes = LfsrDw / 4;
    // Fill in the input vector in col-major order.
    logic [3:0][NumSboxes-1:0][LfsrIdxDw-1:0] matrix_indices;
    for (genvar j = 0; j < LfsrDw; j++) begin : gen_input_idx_map
      assign matrix_indices[j / NumSboxes][j % NumSboxes] = j;
    end
    // Due to the LFSR shifting pattern, the above permutation has the property that the output of
    // SBox(n) is going to be equal to SBox(n+1) in the subsequent cycle (unless the LFSR polynomial
    // modifies some of the associated shifted bits via an XOR tap).
    // We therefore tweak this permutation by rotating and reversing some of the assignment matrix
    // columns. The rotation and reversion operations have been chosen such that this
    // generalizes to all power of two widths supported by the LFSR primitive. For 16bit, this
    // looks as follows:
    //
    // SBox0: 0,  6, 11, 14
    // SBox1: 1,  7, 10, 13
    // SBox2: 2,  4,  9, 12
    // SBox3: 3,  5,  8, 15
    //
    // This can be achieved by:
    //   1) down rotating the second column by NumSboxes/2
    //   2) reversing the third column
    //   3) down rotating the fourth column by 1 and reversing it
    //
    logic [3:0][NumSboxes-1:0][LfsrIdxDw-1:0] matrix_rotrev_indices;
    typedef logic [NumSboxes-1:0][LfsrIdxDw-1:0] matrix_col_t;

    // left-rotates a matrix column by the shift amount
    function automatic matrix_col_t lrotcol(matrix_col_t col, integer shift);
      matrix_col_t out;
      for (int k = 0; k < NumSboxes; k++) begin
        out[(k + shift) % NumSboxes] = col[k];
      end
      return out;
    endfunction : lrotcol

    // reverses a matrix column
    function automatic matrix_col_t revcol(matrix_col_t col);
      return {<<LfsrIdxDw{col}};
    endfunction : revcol

    always_comb begin : p_rotrev
      matrix_rotrev_indices[0] = matrix_indices[0];
      matrix_rotrev_indices[1] = lrotcol(matrix_indices[1], NumSboxes/2);
      matrix_rotrev_indices[2] = revcol(matrix_indices[2]);
      matrix_rotrev_indices[3] = revcol(lrotcol(matrix_indices[3], 1));
    end

    // Read out the matrix rows and linearize.
    logic [LfsrDw-1:0][LfsrIdxDw-1:0] sbox_in_indices;
    for (genvar k = 0; k < LfsrDw; k++) begin : gen_reverse_upper
      assign sbox_in_indices[k] = matrix_rotrev_indices[k % 4][k / 4];
    end

`ifndef SYNTHESIS
      // Check that the permutation is indeed a permutation.
      logic [LfsrDw-1:0] sbox_perm_test;
      always_comb begin : p_perm_check
        sbox_perm_test = '0;
        for (int k = 0; k < LfsrDw; k++) begin
          sbox_perm_test[sbox_in_indices[k]] = 1'b1;
        end
      end
      // All bit positions must be marked with 1.
      `CALIPTRA_ASSERT(SboxPermutationCheck_A, &sbox_perm_test)
`endif

`ifdef FPV_ON
      // Verify that the permutation indeed breaks linear shifting patterns of 4bit input groups.
      // The symbolic variables let the FPV tool select all sbox index combinations and linear shift
      // offsets.
      int shift;
      int unsigned sk, sj;
      `CALIPTRA_ASSUME(SjSkRange_M, (sj < NumSboxes) && (sk < NumSboxes))
      `CALIPTRA_ASSUME(SjSkDifferent_M, sj != sk)
      `CALIPTRA_ASSUME(SjSkStable_M, ##1 $stable(sj) && $stable(sk) && $stable(shift))
      `CALIPTRA_ASSERT(SboxInputIndexGroupIsUnique_A,
          !((((sbox_in_indices[sj * 4 + 0] + shift) % LfsrDw) == sbox_in_indices[sk * 4 + 0]) &&
            (((sbox_in_indices[sj * 4 + 1] + shift) % LfsrDw) == sbox_in_indices[sk * 4 + 1]) &&
            (((sbox_in_indices[sj * 4 + 2] + shift) % LfsrDw) == sbox_in_indices[sk * 4 + 2]) &&
            (((sbox_in_indices[sj * 4 + 3] + shift) % LfsrDw) == sbox_in_indices[sk * 4 + 3])))

      // this checks that the permutations does not preserve neighboring bit positions.
      // i.e. no two neighboring bits are mapped to neighboring bit positions.
      int y;
      int unsigned ik;
      `CALIPTRA_ASSUME(IkYRange_M, (ik < LfsrDw) && (y == 1 || y == -1))
      `CALIPTRA_ASSUME(IkStable_M, ##1 $stable(ik) && $stable(y))
      `CALIPTRA_ASSERT(IndicesNotAdjacent_A, (sbox_in_indices[ik] - sbox_in_indices[(ik + y) % LfsrDw]) != 1)
`endif

    // Use the permutation indices to create the SBox layer
    for (genvar k = 0; k < NumSboxes; k++) begin : gen_sboxes
      logic [3:0] sbox_in;
      assign sbox_in = {lfsr_q[sbox_in_indices[k*4 + 3]],
                        lfsr_q[sbox_in_indices[k*4 + 2]],
                        lfsr_q[sbox_in_indices[k*4 + 1]],
                        lfsr_q[sbox_in_indices[k*4 + 0]]};
      assign sbox_out[k*4 +: 4] = caliptra_prim_cipher_pkg::PRINCE_SBOX4[sbox_in];
    end
  end else begin : gen_out_passthru
    assign sbox_out = lfsr_q;
  end

  // Random output permutation, defined at compile time
  if (StatePermEn) begin : gen_state_perm

    for (genvar k = 0; k < StateOutDw; k++) begin : gen_perm_loop
      assign state_o[k] = sbox_out[StatePerm[k]];
    end

    // if lfsr width is greater than the output, then by definition
    // not every bit will be picked
    if (LfsrDw > StateOutDw) begin : gen_tieoff_unused
      logic unused_sbox_out;
      assign unused_sbox_out = ^sbox_out;
    end

  end else begin : gen_no_state_perm
    assign state_o = StateOutDw'(sbox_out);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_reg
    if (!rst_ni) begin
      lfsr_q <= DefaultSeedLocal;
    end else begin
      lfsr_q <= lfsr_d;
    end
  end


  ///////////////////////
  // shared assertions //
  ///////////////////////

  `CALIPTRA_ASSERT_KNOWN(DataKnownO_A, state_o)

// the code below is not meant to be synthesized,
// but it is intended to be used in simulation and FPV
`ifndef SYNTHESIS
  function automatic logic [LfsrDw-1:0] compute_next_state(logic [LfsrDw-1:0]    lfsrcoeffs,
                                                           logic [EntropyDw-1:0] entropy,
                                                           logic [LfsrDw-1:0]    current_state);
    logic state0;
    logic [LfsrDw-1:0] next_state;

    next_state = current_state;

    // Galois XOR
    if (64'(LfsrType) == 64'("GAL_XOR")) begin
      if (next_state == 0) begin
        next_state = DefaultSeedLocal;
      end else begin
        state0 = next_state[0];
        next_state = next_state >> 1;
        if (state0) next_state ^= lfsrcoeffs;
        next_state ^= LfsrDw'(entropy);
      end
    // Fibonacci XNOR
    end else if (64'(LfsrType) == "FIB_XNOR") begin
      if (&next_state) begin
        next_state = DefaultSeedLocal;
      end else begin
        state0 = ~(^(next_state & lfsrcoeffs));
        next_state = next_state << 1;
        next_state[0] = state0;
        next_state ^= LfsrDw'(entropy);
      end
    end else begin
      $error("unknown lfsr type");
    end

    return next_state;
  endfunction : compute_next_state

  // check whether next state is computed correctly
  // we shift the assertion by one clock cycle (##1) in order to avoid
  // erroneous SVA triggers right after reset deassertion in cases where
  // the precondition is true throughout the reset.
  // this can happen since the disable_iff evaluates using unsampled values,
  // meaning that the assertion may already read rst_ni == 1 on an active
  // clock edge while the flops in the design have not yet changed state.
  `CALIPTRA_ASSERT(NextStateCheck_A, ##1 lfsr_en_i && !seed_en_i |=> lfsr_q ==
      compute_next_state(coeffs, $past(entropy_i), $past(lfsr_q)))

  // Only check this if enabled.
  if (StatePermEn) begin : gen_perm_check
    // Check that the supplied permutation is valid.
    logic [LfsrDw-1:0] lfsr_perm_test;
    initial begin : p_perm_check
      lfsr_perm_test = '0;
      for (int k = 0; k < LfsrDw; k++) begin
        lfsr_perm_test[StatePerm[k]] = 1'b1;
      end
      // All bit positions must be marked with 1.
      `CALIPTRA_ASSERT_I(PermutationCheck_A, &lfsr_perm_test)
    end
  end

`endif

  `CALIPTRA_ASSERT_INIT(InputWidth_A, LfsrDw >= EntropyDw)
  `CALIPTRA_ASSERT_INIT(OutputWidth_A, LfsrDw >= StateOutDw)

  // MSB must be one in any case
  `CALIPTRA_ASSERT(CoeffCheck_A, coeffs[LfsrDw-1])

  // output check
  `CALIPTRA_ASSERT_KNOWN(OutputKnown_A, state_o)
  if (!StatePermEn && !NonLinearOut) begin : gen_output_sva
    `CALIPTRA_ASSERT(OutputCheck_A, state_o == StateOutDw'(lfsr_q))
  end
  // if no external input changes the lfsr state, a lockup must not occur (by design)
  //`CALIPTRA_ASSERT(NoLockups_A, (!entropy_i) && (!seed_en_i) |=> !lockup, clk_i, !rst_ni)
  `CALIPTRA_ASSERT(NoLockups_A, lfsr_en_i && !entropy_i && !seed_en_i |=> !lockup)

  // this can be disabled if unused in order to not distort coverage
  if (ExtSeedSVA) begin : gen_ext_seed_sva
    // check that external seed is correctly loaded into the state
    // rst_ni is used directly as part of the pre-condition since the usage of rst_ni
    // in disable_iff is unsampled.  See #1985 for more details
    `CALIPTRA_ASSERT(ExtDefaultSeedInputCheck_A, (seed_en_i && rst_ni) |=> lfsr_q == $past(seed_i))
  end

  // if the external seed mechanism is not used,
  // there is theoretically no way we end up in a lockup condition
  // in order to not distort coverage, this SVA can be disabled in such cases
  if (LockupSVA) begin : gen_lockup_mechanism_sva
    // check that a stuck LFSR is correctly reseeded
    `CALIPTRA_ASSERT(LfsrLockupCheck_A, lfsr_en_i && lockup && !seed_en_i |=> !lockup)
  end

  // If non-linear output requested, the LFSR width must be a power of 2 and greater than 16.
  if(NonLinearOut) begin : gen_nonlinear_align_check_sva
    `CALIPTRA_ASSERT_INIT(SboxByteAlign_A, 2**$clog2(LfsrDw) == LfsrDw && LfsrDw >= 16)
  end

  if (MaxLenSVA) begin : gen_max_len_sva
`ifndef SYNTHESIS
    // the code below is a workaround to enable long sequences to be checked.
    // some simulators do not support SVA sequences longer than 2**32-1.
    logic [LfsrDw-1:0] cnt_d, cnt_q;
    logic perturbed_d, perturbed_q;
    logic [LfsrDw-1:0] cmp_val;

    assign cmp_val = {{(LfsrDw-1){1'b1}}, 1'b0}; // 2**LfsrDw-2
    assign cnt_d = (lfsr_en_i && lockup)             ? '0           :
                   (lfsr_en_i && (cnt_q == cmp_val)) ? '0           :
                   (lfsr_en_i)                       ? cnt_q + 1'b1 :
                                                       cnt_q;

    assign perturbed_d = perturbed_q | (|entropy_i) | seed_en_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_max_len
      if (!rst_ni) begin
        cnt_q       <= '0;
        perturbed_q <= 1'b0;
      end else begin
        cnt_q       <= cnt_d;
        perturbed_q <= perturbed_d;
      end
    end

    `CALIPTRA_ASSERT(MaximalLengthCheck0_A, cnt_q == 0 |-> lfsr_q == DefaultSeedLocal,
        clk_i, !rst_ni || perturbed_q)
    `CALIPTRA_ASSERT(MaximalLengthCheck1_A, cnt_q != 0 |-> lfsr_q != DefaultSeedLocal,
        clk_i, !rst_ni || perturbed_q)
`endif
  end

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_generic_flop #(
  parameter int               Width      = 1,
  parameter logic [Width-1:0] ResetValue = 0
) (
  input                    clk_i,
  input                    rst_ni,
  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q_o <= ResetValue;
    end else begin
      q_o <= d_i;
    end
  end

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_generic_flop_en #(
  parameter int               Width      = 1,
  parameter bit               EnSecBuf   = 0,
  parameter logic [Width-1:0] ResetValue = 0
) (
  input                    clk_i,
  input                    rst_ni,
  input                    en_i,
  input        [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);

  logic en;
  if (EnSecBuf) begin : gen_en_sec_buf
    caliptra_prim_sec_anchor_buf #(
      .Width(1)
    ) u_en_buf (
      .in_i(en_i),
      .out_o(en)
    );
  end else begin : gen_en_no_sec_buf
    assign en = en_i;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q_o <= ResetValue;
    end else if (en) begin
      q_o <= d_i;
    end
  end

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_generic_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);

  logic [Width-1:0] inv;
  assign inv = ~in_i;
  assign out_o = ~inv;

endmodule
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define CALIPTRA_PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef CALIPTRA_SVA
`define CALIPTRA_SVA

// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define CALIPTRA_ASSERT_RPT(name)                                                  \
`ifdef UVM                                                                \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                \
                             name, `__FILE__, `__LINE__));                \
`else                                                                     \
  $fatal(1, "[CALIPTRA_ASSERT FAILED] [%m] %s (%s:%0d)",name, `__FILE__, `__LINE__);  \
`endif

// Assert a concurrent property directly.
`define CALIPTRA_ASSERT(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST)  \
`ifdef CLP_ASSERT_ON                                                           \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) (prop))    \
    else begin                                                                 \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                   \
    end                                                                        \
`endif

// Assert a concurrent property NEVER happens
`define CALIPTRA_ASSERT_NEVER(assert_name, prop, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef CLP_ASSERT_ON                                                            \
  assert_name: assert property (@(posedge clk) disable iff (~rst_b) not (prop)) \
    else begin                                                                  \
        `CALIPTRA_ASSERT_RPT(`STRINGIFY(assert_name))                                    \
    end                                                                         \
`endif

// Assert that signal is not x
`define CALIPTRA_ASSERT_KNOWN(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(assert_name, !$isunknown(sig), clk, rst_b)

// Assert that a vector of signals is mutually exclusive
`define CALIPTRA_ASSERT_MUTEX(assert_name, sig, clk = `CALIPTRA_ASSERT_DEFAULT_CLK, rst_b = `CALIPTRA_ASSERT_DEFAULT_RST) \
    `CALIPTRA_ASSERT(assert_name, $onehot0(sig), clk, rst_b)

`endif
`ifndef CALIPTRA_SVA
// Default clk and reset signals used by assertion macros below.
`define CALIPTRA_ASSERT_DEFAULT_CLK clk_i
`define CALIPTRA_ASSERT_DEFAULT_RST !rst_ni
`endif

// Converts an arbitrary block of code into a Verilog string
`define CALIPTRA_PRIM_STRINGIFY(__x) `"__x`"

// CALIPTRA_ASSERT_ERROR logs an error message with either `uvm_error or with $error.
//
// This somewhat duplicates `DV_ERROR macro defined in hw/dv/sv/dv_utils/dv_macros.svh. The reason
// for redefining it here is to avoid creating a dependency.
`define CALIPTRA_ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                                        \
  uvm_pkg::uvm_report_error("CALIPTRA_ASSERT FAILED", `CALIPTRA_PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                         \
`else                                                                                             \
  $error("%0t: (%0s:%0d) [%m] [CALIPTRA_ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `CALIPTRA_PRIM_STRINGIFY(__name));                                                                \
`endif

// This macro is suitable for conditionally triggering lint errors, e.g., if a Sec parameter takes
// on a non-default value. This may be required for pre-silicon/FPGA evaluation but we don't want
// to allow this for tapeout.
`define CALIPTRA_ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;                   \
  always_comb begin                                           \
    logic unused_assert_static_lint_error;                    \
    unused_assert_static_lint_error = __name'(1'b1);          \
  end

// Static assertions for checks inside SV packages. If the conditions is not true, this will
// trigger an error during elaboration.
`define CALIPTRA_ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name();          \
    bit unused_bit [((__prop) ? 1 : -1)];                              \
    unused_bit = '{default: 1'b0};                                     \
    return unused_bit[0];                                              \
  endfunction

// The basic helper macros are actually defined in "implementation headers". The macros should do
// the same thing in each case (except for the dummy flavour), but in a way that the respective
// tools support.
//
// If the tool supports assertions in some form, we also define CALIPTRA_INC_ASSERT (which can be 
// used to hide signal definitions that are only used for assertions).
//
// The list of basic macros supported is:
//
//  CALIPTRA_ASSERT_I:     Immediate assertion. Note that immediate assertions are sensitive to simulation
//                         glitches.
//
//  CALIPTRA_ASSERT_INIT:  Assertion in initial block. Can be used for things like parameter checking.
//
//  CALIPTRA_ASSERT_INIT_NET: Assertion in initial block. Can be used for initial value of a net.
//
//  CALIPTRA_ASSERT_FINAL: Assertion in final block. Can be used for things like queues being empty at end of
//                         sim, all credits returned at end of sim, state machines in idle at end of sim.
//
//  CALIPTRA_ASSERT:       Assert a concurrent property directly. It can be called as a module (or
//                         interface) body item.
//
//                         Note: We use (__rst !== '0) in the disable iff statements instead of (__rst ==
//                         '1). This properly disables the assertion in cases when reset is X at the
//                         beginning of a simulation. For that case, (reset == '1) does not disable the
//                         assertion.
//
//  CALIPTRA_ASSERT_NEVER: Assert a concurrent property NEVER happens
//
//  CALIPTRA_ASSERT_KNOWN: Assert that signal has a known value (each bit is either '0' or '1') after reset.
//                         It can be called as a module (or interface) body item.
//
//  CALIPTRA_COVER:        Cover a concurrent property
//
//  CALIPTRA_ASSUME:       Assume a concurrent property
//
//  CALIPTRA_ASSUME_I:     Assume an immediate property

`ifdef VERILATOR
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif SYNTHESIS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that don't support assertions. See
// caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)
`define CALIPTRA_ASSERT_INIT(__name, __prop)
`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)
`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif
`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`define CALIPTRA_ASSUME_I(__name, __prop)
`elsif YOSYS
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for formal verification with Yosys. See caliptra_prim_assert.sv
// for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop)    \
  always_comb begin : __name        \
    assert (__prop);                \
  end

`define CALIPTRA_ASSERT_INIT(__name, __prop)    \
  initial begin : __name               \
    assert (__prop);                   \
  end

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop) \
  initial begin : __name                \
    #1ps assert (__prop);               \
  end

// This doesn't make much sense for a formal tool (we never get to the final block!)
`define CALIPTRA_ASSERT_FINAL(__name, __prop)

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assert (__prop);                                       \
  end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                             \
    if (! (__rst !== '0)) __name: assert (! (__prop));                                         \
  end

// Yosys uses 2-state logic, so this doesn't make sense here
`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin : __name                                             \
    cover ((! (__rst !== '0)) && (__prop));                                             \
  end

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  always_ff @(posedge __clk) begin                                                       \
    if (! (__rst !== '0)) __name: assume (__prop);                                       \
  end

`define CALIPTRA_ASSUME_I(__name, __prop)              \
  always_comb begin : __name                  \
    assume (__prop);                          \
  end
 `define CALIPTRA_INC_ASSERT
`else
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by caliptra_prim_assert.sv for tools that support full SystemVerilog and SVA syntax.
// See caliptra_prim_assert.sv for documentation for each of the macros.

`define CALIPTRA_ASSERT_I(__name, __prop) \
  __name: assert (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end

// Formal tools will ignore the initial construct, so use static assertion as a workaround.
// This workaround terminates design elaboration if the __prop predict is false.
// It calls $fatal() with the first argument equal to 2, it outputs the statistics about the memory
// and CPU time.
`define CALIPTRA_ASSERT_INIT(__name, __prop)                                                  \
`ifdef FPV_ON                                                                        \
  if (!(__prop)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",         \
                        (__name), (__prop));                                         \
`else                                                                                \
  initial begin                                                                      \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \
`endif

`define CALIPTRA_ASSERT_INIT_NET(__name, __prop)                                                   \
  initial begin                                                                      \
    // When a net is assigned with a value, the assignment is evaluated after        \
    // initial in Xcelium. Add 1ps delay to check value after the assignment is      \
    // completed.                                                                    \
    #1ps;                                                                            \
    __name: assert (__prop)                                                          \
      else begin                                                                     \
        `CALIPTRA_ASSERT_ERROR(__name)                                                        \
      end                                                                            \
  end                                                                                \

`define CALIPTRA_ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `CALIPTRA_ASSERT_ERROR(__name)                                                \
      end                                                                    \
  end

`ifndef CALIPTRA_SVA
`define CALIPTRA_ASSERT(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSERT_NEVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `CALIPTRA_ASSERT_ERROR(__name)                                                                    \
    end

`define CALIPTRA_ASSERT_KNOWN(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, !$isunknown(__sig), __clk, __rst)
`endif

`define CALIPTRA_COVER(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

`define CALIPTRA_ASSUME(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `CALIPTRA_ASSERT_ERROR(__name)                                                              \
    end

`define CALIPTRA_ASSUME_I(__name, __prop) \
  __name: assume (__prop)        \
    else begin                   \
      `CALIPTRA_ASSERT_ERROR(__name)      \
    end
 `define CALIPTRA_INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define CALIPTRA_ASSERT_PULSE(__name, __sig, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define CALIPTRA_ASSERT_IF(__name, __prop, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define CALIPTRA_ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `CALIPTRA_ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `CALIPTRA_ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// Note that the existing set of CALIPTRA_ASSERT macros specified above shall be used for FPV,
// thereby ensuring that the assertions are evaluated during DV simulations as well.

// CALIPTRA_ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `CALIPTRA_ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// CALIPTRA_ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define CALIPTRA_ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `CALIPTRA_ASSUME_I(__name, __prop)         \
`endif

// CALIPTRA_COVER_FPV
// Cover a concurrent property during formal verification
`define CALIPTRA_COVER_FPV(__name, __prop, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `CALIPTRA_COVER(__name, __prop, __clk, __rst)                                                     \
`endif

// FPV assertion that proves that the FSM control flow is linear (no loops)
// The sequence triggers whenever the state changes and stores the current state as "initial_state".
// Then thereafter we must never see that state again until reset.
// It is possible for the reset to release ahead of the clock.
// Create a small "gray" window beyond the usual rst time to avoid
// checking.
`define CALIPTRA_ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `CALIPTRA_ASSERT_DEFAULT_CLK, __rst = `CALIPTRA_ASSERT_DEFAULT_RST) \
  `ifdef CALIPTRA_INC_ASSERT                                                                                              \
     bit __name``_cond;                                                                                          \
     always_ff @(posedge __clk or posedge __rst) begin                                                           \
       if (__rst) begin                                                                                          \
         __name``_cond <= 0;                                                                                     \
       end else begin                                                                                            \
         __name``_cond <= 1;                                                                                     \
       end                                                                                                       \
     end                                                                                                         \
     property __name``_p;                                                                                        \
       __type initial_state;                                                                                     \
       (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                   \
           (__state != initial_state) until (__rst == 1'b1);                                                     \
     endproperty                                                                                                 \
   `CALIPTRA_ASSERT(__name, __name``_p, __clk, __rst)                                                                     \
  `endif

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// // Macros and helper code for security countermeasures.

`ifndef PRIM_ASSERT_SEC_CM_SVH
`define CALIPTRA_PRIM_ASSERT_SEC_CM_SVH

`define _CALIPTRA_SEC_CM_ALERT_MAX_CYC 30

// Helper macros
`define CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, ERR_NAME_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ALERT_.alert_p)) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif \
  `CALIPTRA_ASSUME_FPV(``NAME_``TriggerAfterAlertInit_S, $stable(rst_ni) == 0 |-> \
                       PRIM_HIER_.ERR_NAME_ == 0 [*10])

`define CALIPTRA_ASSERT_ERROR_TRIGGER_ERR(NAME_, PRIM_HIER_, ERR_, GATE_, MAX_CYCLES_, ERR_NAME_, CLK_, RST_) \
  `CALIPTRA_ASSERT(FpvSecCm``NAME_``, \
          $rose(PRIM_HIER_.ERR_NAME_) && !(GATE_) \
          |-> ##[0:MAX_CYCLES_] (ERR_), CLK_, RST_) \
  `ifdef CALIPTRA_INC_ASSERT \
  assign PRIM_HIER_.unused_assert_connected = 1'b1; \
  `endif

// macros for security countermeasures that will trigger alert
`define CALIPTRA_ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, unused_err_o)

`define CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_ERROR_TRIGGER_ALERT(NAME_, PRIM_HIER_, ALERT_, GATE_, MAX_CYCLES_, err_o)

`define CALIPTRA_ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = `_CALIPTRA_SEC_CM_ALERT_MAX_CYC) \
  `CALIPTRA_ASSERT_PRIM_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, \
    REG_TOP_HIER_.u_caliptra_prim_reg_we_check.u_caliptra_prim_onehot_check, ALERT_, GATE_, MAX_CYCLES_)

`endif // PRIM_ASSERT_SEC_CM_SVH
// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define CALIPTRA_PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define CALIPTRA_PRIM_FLOP_CLK clk_i
`define CALIPTRA_PRIM_FLOP_RST rst_ni
`define CALIPTRA_PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// TODO: define other variations of register macros so that they can be used throughout all designs
// to make the code more concise.

// Register with asynchronous reset.
`define CALIPTRA_PRIM_FLOP_A(__d, __q, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST) \
  always_ff @(posedge __clk or negedge __rst_n) begin \
    if (!__rst_n) begin                               \
      __q <= __resval;                                \
    end else begin                                    \
      __q <= __d;                                     \
    end                                               \
  end

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// Simulation tools typically infer FSMs and report coverage for these separately. However, tools
// like Xcelium and VCS seem to have problems inferring FSMs if the state register is not coded in
// a behavioral always_ff block in the same hierarchy. To that end, this uses a modified variant
// with a second behavioral register definition for RTL simulations so that FSMs can be inferred.
// Note that in this variant, the __q output is disconnected from caliptra_prim_sparse_fsm_flop and attached
// to the behavioral flop. An assertion is added to ensure equivalence between the
// caliptra_prim_sparse_fsm_flop output and the behavioral flop output in that case.
`define CALIPTRA_PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `CALIPTRA_PRIM_FLOP_RESVAL, __clk = `CALIPTRA_PRIM_FLOP_CLK, __rst_n = `CALIPTRA_PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
  `ifdef CALIPTRA_SIMULATION                                   \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en), \
      .CustomForceName(`CALIPTRA_PRIM_STRINGIFY(__q))          \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o (         )                            \
    );                                                \
    `CALIPTRA_PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)  \
    `CALIPTRA_ASSERT(``__name``_A, __q === ``__name``.state_o) \
  `else                                               \
    caliptra_prim_sparse_fsm_flop #(                           \
      .StateEnumT(__type),                            \
      .Width($bits(__type)),                          \
      .ResetValue($bits(__type)'(__resval)),          \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)  \
    ) __name (                                        \
      .clk_i   ( __clk   ),                           \
      .rst_ni  ( __rst_n ),                           \
      .state_i ( __d     ),                           \
      .state_o ( __q     )                            \
    );                                                \
  `endif

`endif // PRIM_FLOP_MACROS_SV

`endif // PRIM_ASSERT_SV

module caliptra_prim_sec_anchor_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);

  caliptra_prim_buf #(
    .Width(Width)
  ) u_secure_anchor_buf (
    .in_i,
    .out_o
  );

endmodule
`undef SYNTHESIS
