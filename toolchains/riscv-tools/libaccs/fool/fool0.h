#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>
#include <stdio.h>
#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }

class fool0_t : public extension_t {
public:
  //gemmini_t() : cause(0), aux(0), debug(false) {}
  const char* name() { return "fool0"; }
  fool0_t() {
    memset(acc, 0, sizeof(acc));
  }
  
  reg_t custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2)
  {
    reg_t prev_acc = acc[insn.rs2];

    if (insn.rs2 >= num_acc)
      illegal_instruction();

    switch (insn.funct%64)
    {
      case 0: // acc <- xs1
        /*
        printf("Number of extensions: %d\n", p->get_isa().get_extensions().size()); //- This was 0
        for (const auto& element: p->get_isa().get_extensions()){
          printf("%s\n", element.c_str());
        }
        */
        acc[insn.rs2] = xs1;
        break;
      case 1: // xd <- acc (the only real work is the return statement below)
        break;
      case 2: // acc[rs2] <- Mem[xs1]
        acc[insn.rs2] = p->get_mmu()->load<uint64_t>(xs1);
        break;
      case 3: // acc[rs2] <- accX + xs1
        acc[insn.rs2] += xs1;
        break;
      default:
        illegal_instruction();
    }

    return prev_acc; // in all cases, xd <- previous value of acc[rs2]
  }
  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();

private:
  static const int num_acc = 4;
  reg_t acc[num_acc];
};
#ifndef TOP
REGISTER_EXTENSION(fool0, []() { return new fool0_t; })
#endif
