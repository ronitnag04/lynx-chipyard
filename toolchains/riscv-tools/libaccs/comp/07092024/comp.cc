#include "comp.h"
#include "stdio.h"

#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

using namespace std;

comp_t::comp_t(){
  latency = 0;
  ip = 0; isize = 0; wksp = 0; op = 0; cmpflag = 0;
  hist_sram_size = 0;
  size_processed = 0;

  printf("DEBUG: " STRINGIZE_VALUE_OF(CUR_DIR) "\n");
  printf("DEBUG: " STRINGIZE_VALUE_OF(ZSTD_BIN) "\n");
}

void comp_t::write_to_file(char* file_str, reg_t size, reg_t start_ptr) {
  printf("Writing to file: %s\n", file_str);
  char buffer[1024];
  int ret = snprintf(buffer, 1024, "rm -rf %s", file_str);
  printf("First deleting with: '%s'\n", buffer);
  system(buffer);
  FILE* file = fopen(file_str, "w");
  assert(file != NULL);
  int size_processed = 0;
  while(size_processed < size){
    uint8_t temp = p->get_mmu()->load<uint8_t>(start_ptr + size_processed);
    fwrite(&temp, sizeof(uint8_t), 1, file);
    ++size_processed;
    //size_processed += (isize-size_processed>=8 ? 8 : isize-size_processed);
  }
  fclose(file);
  printf("Done writing to file: %s\n", file_str);
}

reg_t comp_t::custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch (insn.funct){
    case 0: // Fence
      break;

    // Zstd functions
    case 9: // hash table size
      htsize_log2_comp = xs1;
      break;
    case 8: // history size
      hist_comp = xs1;
      break;
    case 10:
      latency_comp = xs1; has_intermediate_cache_comp = xs2;
      break;
    case 1: // src info
      ip_comp = xs1; isize_comp = xs2;
      break;
    case 2: // lit buf info
      litbuf_comp = xs1; litbufsize_comp = xs2;
      break;
    case 3: // seq buf info
      seqbuf_comp = xs1; seqbuf_comp = xs2;
      break;
    case 4: // dest info
      op_comp = xs1; cmpflag_comp = xs2;
      break;
    case 5: // clevel info
      clevel_comp = xs1;
      printf("DEBUG: Doing compression\n");
      // Just use the zstd binary
      // 1. Load from ip(mmu) and store into a file(file pointer)
      // 2. Compress that file(zstd binary) and store to op(mmu)
      write_to_file(STRINGIZE_VALUE_OF(CUR_DIR) "/decomped", isize_comp, ip_comp);
      system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/comped");
      system(STRINGIZE_VALUE_OF(ZSTD_BIN) " " STRINGIZE_VALUE_OF(CUR_DIR) "/decomped -o " STRINGIZE_VALUE_OF(CUR_DIR) "/comped");
      {
        printf("DEBUG: Finished doing host zstd\n");
        FILE* file2 = fopen(STRINGIZE_VALUE_OF(CUR_DIR) "/comped", "r");
        fseek(file2, 0, SEEK_END);
        osize = ftell(file2);
        fseek(file2, 0, SEEK_SET);
        size_processed = 0;
        while(size_processed<osize){
          uint8_t temp;
          fread(&temp, sizeof(uint8_t), 1, file2);
          p->get_mmu()->store<uint8_t>(op_comp+size_processed, temp);
          ++size_processed;
          //size_processed += (osize-size_processed>=8 ? 8 : osize-size_processed);
        }
        fclose(file2);
        printf("DEBUG: Wrote data back to memory\n");
      }
      size_processed = 0;
      break;
    case 11: // Check completion
      printf("DEBUG: check completion\n");
      cmpflag = osize; // Return output size
      //cmpflag = (requests_processed==somevalue) ? 1 : 0;
      return cmpflag;
      break;

    default:
      illegal_instruction();
      break;
  }
  return 0;
}


#ifndef TOP
define_custom_func(comp_t, "comp", comp_custom0, custom0)

std::vector<insn_desc_t> comp_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_custom_insn(insns, ROCC_OPCODE2, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, comp_custom0);
  return insns;
}

std::vector<disasm_insn_t*> comp_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}
REGISTER_EXTENSION(comp, []() { return new comp_t; })
#endif
