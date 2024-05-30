#define TOP 1

#ifndef TOP
#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>
#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }
#endif

#include "fool0.h"
//#include "fool1.h"
//#include "fool4.h"


class fooltop_t : public extension_t {
public:
  //gemmini_t() : cause(0), aux(0), debug(false) {}
  const char* name() { return "fooltop"; }
  fooltop_t() {
    //f0 = fool0_t();
    //f1 = fool1_t();
    //f4 = fool4_t();
  }
  
  reg_t custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2)
  {
    if( (insn.funct>>6)%2 == 0){ //Opcode 0
      return f0.custom0(insn, xs1, xs2);
    }
    //else{ //Opcode 4
    //  return f4.custom0(insn, xs1, xs2);
    //}
  }
/*
  reg_t custom1(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2)
  {
    return f1.custom1(insn, xs1, xs2);
  }
*/
  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();

private:
  fool0_t f0;
  //fool1_t f1;
  //fool4_t f4;
};
//REGISTER_EXTENSION(fooltop, []() { return new fooltop_t; })
/*
class register_fooltop{
  public:
    register_fooltop(){
      register_extension("fooltop", [](){return new fooltop_t;}); 
    }
}; static register_fooltop dummy_fooltop;
*/
