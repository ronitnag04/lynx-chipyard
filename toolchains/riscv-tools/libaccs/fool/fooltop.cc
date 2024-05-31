#include "fooltop.h"
using namespace std;

// #define define_custom_func(type_name, ext_name_str, func_name, method_name)
define_custom_func(fooltop_t, "fooltop", fooltop_custom0, custom0)
//define_custom_func(fooltop_t, "fooltop", fooltop_custom1, custom1)

std::vector<insn_desc_t> fooltop_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  //How do you know the opcode in advance?
  push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fooltop_custom0);
  //push_custom_insn(insns, ROCC_OPCODE1, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fooltop_custom1);
  //push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fool_rocc_custom0);
  //push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fool_rocc_custom0);  
  return insns;
}

std::vector<disasm_insn_t*> fooltop_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}

