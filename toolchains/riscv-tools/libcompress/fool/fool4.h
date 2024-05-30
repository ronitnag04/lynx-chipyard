#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>

#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }

class fool4_t : public extension_t {
public:
  //gemmini_t() : cause(0), aux(0), debug(false) {}
  const char* name() { return "fool4"; }
  fool4_t() {
    memset(reg, 0, sizeof(reg));
  }  

  reg_t custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2)
  {
    switch (insn.funct%64)
    {
      case 0:
        dprintf("Accel 1: Fence\n");
        break;
      case 1:
        dprintf("Accel 1: Add\n");
        reg[0] = xs1 + xs2;
        break;
      case 2:
        dprintf("Accel 1: Check value\n");
        break;
      default:
        illegal_instruction();
    }

    return reg[0]; // in all cases, xd <- previous value of acc[rs2]
  }

  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();

 

private:
  reg_t reg[1];
};
#ifndef TOP
REGISTER_EXTENSION(fool4, []() { return new fool4_t; })
#endif


