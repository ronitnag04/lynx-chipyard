//************************************************************************
// Copyright 2022 Massachusets Institute of Technology
// SPDX License Identifier: BSD-2-Clause
//
// File Name:       aes_192_mock_tss.sv
// Program:         Common Evaluation Platform (CEP)
// Description:
// Notes:
//************************************************************************
`timescale 1ns/1ns

module aes_192_mock_tss (

    // Clock and Reset
    input wire            clk,
    input wire            rst,

    // Core I/O
    input wire            start,
    input wire [127:0]    state,
    input wire [191:0]    key,
    output wire [127:0]   out,
    output wire           out_valid
);

  // The following parameters are used by the AES instance of the Mock Technique Specific Shim (TSS)
  localparam AES_MOCK_TSS_NUM_KEY_WORDS       = 2;
  localparam [63:0] AES_MOCK_TSS_KEY_WORDS [0:AES_MOCK_TSS_NUM_KEY_WORDS - 1] = '{
      64'hAE53456789ABCDEF,
      64'hFEDCBA9876543210
  };

  // Internal signals & localparams
  localparam KEY_WORDS          = AES_MOCK_TSS_NUM_KEY_WORDS;
  wire [(64*KEY_WORDS) - 1:0]   mock_tss_state;

  //------------------------------------------------------------------
  // Create the Mock TSS input into the original core
  //------------------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < KEY_WORDS; i = i + 1) begin
      assign mock_tss_state[64*i +: 64] = AES_MOCK_TSS_KEY_WORDS[i] ^
                                          state[64*i +: 64];
    end
  endgenerate
  //------------------------------------------------------------------



  //------------------------------------------------------------------
  // Instantiate the original core
  //------------------------------------------------------------------
  aes_192 aes_192_inst (
    .clk          (clk),
    .rst          (rst),
    .start        (start),
    .state        (mock_tss_state),
    .key          (key),
    .out          (out),
    .out_valid    (out_valid)
  );
  //------------------------------------------------------------------

endmodule
