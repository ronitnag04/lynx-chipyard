#include "fool0.h"
#ifndef TOP
using namespace std;
define_custom_func(fool0_t, "fool0", fool0_custom0, custom0)

std::vector<insn_desc_t> fool0_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, fool0_custom0);
  return insns;
}

std::vector<disasm_insn_t*> fool0_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}
#endif
