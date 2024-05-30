#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>

#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }

class memcpy_t : public extension_t {
public:
  //Function for returning the extension name
  const char* name() { return "memcpy"; }
  //Initialize the architectural state
  memcpy_t();
  //Custom fn using opcode 0
  reg_t custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2);
  
  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();


private:
  //Architectural states
  reg_t ip;
  reg_t isize;
  reg_t size_processed;
  reg_t op;
  reg_t cmpflag;
  reg_t counter;
};
