#include "fool4.h"
#ifndef TOP
using namespace std;
// #define define_custom_func(type_name, ext_name_str, func_name, method_name)
// define_custom_func(gemmini_t, "gemmini", gemmini_custom3, custom3)
define_custom_func(fool4_t, "fool4", fool4_custom0, custom0)

std::vector<insn_desc_t> fool4_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  //How do you know the opcode in advance?
  push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fool4_custom0);
  return insns;
}

std::vector<disasm_insn_t*> fool4_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}
#endif
