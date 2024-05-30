#include <riscv/rocc.h>
#include <riscv/mmu.h>
#include <cstring>
#include <iostream>

#define dprintf(...) { if (p->get_log_commits_enabled()) printf(__VA_ARGS__); }

class proto_t : public extension_t {
public:
  //Function for returning the extension name
  const char* name() { return "proto"; }
  //Initialize the architectural state
  proto_t();
  //Custom fn using opcode 1
  reg_t custom1(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2);
  
  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();


private:
  //Architectural states. Not really used for execution.
  //Deserializer
  reg_t descriptor_table_ptr, dest_base_addr;
  reg_t base_ptr, min_field_no_and_input_length;
  reg_t fixed_alloc_region_addr, array_alloc_region_addr;
  //Serializer

};
