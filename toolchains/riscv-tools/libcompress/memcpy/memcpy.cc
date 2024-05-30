#include "memcpy.h"
using namespace std;
memcpy_t::memcpy_t(){
  //Reset the architectural state
  ip = 0;
  isize = 0; size_processed = 0;
  op = 0;
  cmpflag = 0;
}

reg_t memcpy_t::custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch(insn.funct % 64){
    case 0: //FENCE
      break;
    case 1: //Get input source info
      ip = xs1; isize = xs2; size_processed = 0;
      break;
    case 2: //Get output address info
      op = xs1; cmpflag = xs2;
      while(size_processed<isize){
        uint64_t temp = p->get_mmu()->load<uint64_t>(ip+size_processed);
        p->get_mmu()->store<uint64_t>(op+size_processed, temp);
        size_processed += (isize-size_processed>=8 ? 8 : isize-size_processed);
      }
      break;
    case 3: //Check completion
      cmpflag = isize==size_processed ? 1 : 0;
      return cmpflag;
      break;
    case 4: //Custom function added to check the output.
      return p->get_mmu()->load<uint64_t>(op);
      break;
    default:
      illegal_instruction();
      break;
  }
  return isize;
}

#ifndef TOP
define_custom_func(memcpy_t, "memcpy", memcpy_custom0, custom0)

std::vector<insn_desc_t> memcpy_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, memcpy_custom0);
  return insns;
}

std::vector<disasm_insn_t*> memcpy_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}

REGISTER_EXTENSION(memcpy, []() { return new memcpy_t; })
#endif

