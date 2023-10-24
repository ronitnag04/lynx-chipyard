module aes_cipher_core_wrapper
(
  input  logic                        clk_i,
  input  logic                        rst_ni,

  // Input handshake signals
  input  logic                       in_valid_i,
  output logic                       in_ready_o,

  // Output handshake signals
  output logic                       out_valid_o,
  input  logic                       out_ready_i,

  // Control and sync signals
  input  logic                  [1:0] op_i,
  input  logic                  [2:0] key_len_i,
  input  logic                        crypt_i,
  input  logic                        dec_key_gen_i,
  input  logic                        prng_reseed_i,
  output logic                        alert_o,

  // Pseudo-random data for register clearing
  input  logic                 [63:0] prd_clearing_i_0,
  input  logic                 [63:0] prd_clearing_i_1,

  // Masking PRNG
  input  logic                        force_masks_i, // Useful for SCA only.
  output logic                [127:0] data_in_mask_o,
  output logic                        entropy_req_o,
  input  logic                        entropy_ack_i,
  input  logic                 [31:0] entropy_i,

  // I/O data & initial key
  input  logic                [127:0] state_init_i_0,
  input  logic                [127:0] state_init_i_1,
  input  logic                [255:0] key_init_i_0,
  input  logic                [255:0] key_init_i_1,
  output logic                [127:0] state_o_0,
  output logic                [127:0] state_o_1
);

  import aes_pkg::*;

  localparam bit          SecMasking   = 1;
  localparam sbox_impl_e  SecSBoxImpl  = SecMasking ? SBoxImplDom : SBoxImplCanright;
  localparam int          NumShares    = SecMasking ?           2 :                1;

  sp2v_e in_valid_i_conv;
  sp2v_e out_ready_i_conv;
  logic in_ready_o;
  logic out_valid_o;
  sp2v_e crypt_i_conv;
  sp2v_e dec_key_gen_i_conv;
  sp2v_e in_ready_o_conv;
  sp2v_e out_valid_o_conv;

  assign in_valid_i_conv = in_valid_i ? SP2V_HIGH : SP2V_LOW;
  assign out_ready_i_conv = out_ready_i ? SP2V_HIGH : SP2V_LOW;
  assign in_ready_o = (in_ready_o_conv == SP2V_HIGH) ? '1 : '0;
  assign out_valid_o = (out_valid_o_conv == SP2V_HIGH) ? '1 : '0;
  assign crypt_i_conv = crypt_i ? SP2V_HIGH : SP2V_LOW;
  assign dec_key_gen_i_conv = dec_key_gen_i ? SP2V_HIGH : SP2V_LOW;

  logic  [3:0][3:0][7:0] state_init [NumShares];
  assign state_init[0] = state_init_i_0;
  assign state_init[1] = state_init_i_1;

  logic  [7:0][31:0] key_init [NumShares];
  assign key_init[0] = key_init_i_0;
  assign key_init[1] = key_init_i_1;

  logic  [3:0][3:0][7:0] state_done [NumShares];
  assign state_o_0 = state_done[0];
  assign state_o_1 = state_done[1];

  aes_cipher_core #(
    .SecMasking  ( SecMasking  ),
    .SecSBoxImpl ( SecSBoxImpl )
  ) u_aes_cipher_core (
    .clk_i            ( clk_i             ),
    .rst_ni           ( rst_ni            ),

    .in_valid_i       ( in_valid_i_conv   ),
    .in_ready_o       ( in_ready_o_conv   ),

    .out_valid_o      ( out_valid_o_conv  ),
    .out_ready_i      ( out_ready_i_conv  ),

    .cfg_valid_i      ( 1'b1              ), // Used for gating assertions only.
    .op_i             ( ciph_op_e'(op_i)      ),
    .key_len_i        ( key_len_e'(key_len_i) ),
    .crypt_i          ( crypt_i_conv      ),
    .crypt_o          (                   ), // Ignored.
    .dec_key_gen_i    ( dec_key_gen_i_conv),
    .dec_key_gen_o    (                   ), // Ignored.
    .prng_reseed_i    ( prng_reseed_i     ),
    .prng_reseed_o    (                   ), // Ignored.
    .key_clear_i      ( 1'b0              ), // Ignored.
    .key_clear_o      (                   ), // Ignored.
    .data_out_clear_i ( 1'b0              ), // Ignored.
    .data_out_clear_o (                   ), // Ignored.
    .alert_fatal_i    ( 1'b0              ), // Ignored.
    .alert_o          ( alert_o           ), // Ignored.

    .prd_clearing_i   ( '{prd_clearing_i_1, prd_clearing_i_0} ),

    .force_masks_i    ( 1'b0              ), // Ignored.
    .data_in_mask_o   ( data_in_mask_o    ),
    .entropy_req_o    ( entropy_req_o     ),
    .entropy_ack_i    ( entropy_ack_i     ),
    .entropy_i        ( entropy_i         ),

    .state_init_i     ( state_init ),
    .key_init_i       ( key_init ),
    .state_o          ( state_done )
  );

endmodule
