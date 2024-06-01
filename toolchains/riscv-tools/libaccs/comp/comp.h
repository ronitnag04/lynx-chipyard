#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }

class comp_t : public extension_t {
public:
  const char* name() { return "comp"; }
  comp_t();

  reg_t custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2);
  void write_to_file(char* file_str, reg_t size, reg_t start_ptr);

  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();

private:
// Decompressor
  //Actually we only need algorithm, ip, isize, and op?
  reg_t algorithm;
  reg_t latency;
  reg_t ip, isize; //input pointer, input size
  reg_t wksp; //workspace: space for intermediate outputs
  reg_t op, cmpflag; //output pointer, completion flag
  reg_t hist_sram_size; // history sram size

  // Doesn't exist in the accelerator architecture, but needed for C model
  uint64_t size_processed;
  uint64_t osize;

// Compressor
  reg_t ip_comp, isize_comp;
  reg_t litbuf_comp, litbufsize_comp;
  reg_t seqbuf_comp, seqbufsize_comp;
  reg_t op_comp, cmpflag_comp;
  reg_t clevel_comp;
  reg_t htsize_log2_comp;
  reg_t hist_comp;
  reg_t latency_comp, has_intermediate_cache_comp;
};
