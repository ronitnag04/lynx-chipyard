#include "rerocc_cluster.h"

#include <riscv/mmu.h>
#include <riscv/rerocc.h>

rerocc_cluster_t::rerocc_cluster_t() {
  memcpy_state[0] = {0};
  memcpy_state[1] = {0};
  aes_state[0] = {0};
  aes_state[1] = {0};
  compress_state[0] = {0};
  decompress_state[0] = {0};

  printf("DEBUG: " STRINGIZE_VALUE_OF(CUR_DIR) "\n");
  printf("DEBUG: " STRINGIZE_VALUE_OF(SNAPPY_COMP_BIN) "\n");
  printf("DEBUG: " STRINGIZE_VALUE_OF(SNAPPY_DECOMP_BIN) "\n");
}

reg_t rerocc_cluster_t::memcpy(memcpy_state_t* memcpy_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch(insn.funct){
    case 0: //FENCE
      break;
    case 1: //Get input source info
      memcpy_state->ip = xs1;
      memcpy_state->isize = xs2;
      memcpy_state->size_processed = 0;
      break;
    case 2: //Get output address info
      //printf("src=0x%lx sz=0x%lx dst=0x%lx cmgflagptr=0x%lx\n", memcpy_state->ip, memcpy_state->isize, xs1, xs2);
      memcpy_state->op = xs1;
      memcpy_state->cmpflag = xs2;
      while (memcpy_state->size_processed < memcpy_state->isize) {
        uint8_t temp = p->get_mmu()->load<uint8_t>(memcpy_state->ip + memcpy_state->size_processed);
        p->get_mmu()->store<uint8_t>(memcpy_state->op + memcpy_state->size_processed, temp);
        memcpy_state->size_processed += (memcpy_state->isize - memcpy_state->size_processed >= 1 ? 1 : memcpy_state->isize - memcpy_state->size_processed);
      }
      break;
    case 3: //Check completion
      p->get_mmu()->store<uint64_t>(memcpy_state->cmpflag, memcpy_state->isize == memcpy_state->size_processed ? 1 : 0);
      //printf("m[cmpflg]=0x%lx\n", memcpy_state->isize == memcpy_state->size_processed ? 1 : 0);
      return 1; // dummy
      break;
    case 4: //Custom function added to check the output.
      return p->get_mmu()->load<uint64_t>(memcpy_state->op);
      break;
    default:
      illegal_instruction();
      break;
  }
  return memcpy_state->isize;
}

reg_t rerocc_cluster_t::aes256cbc(aes_state_t* aes_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch(insn.funct){
    case 0: //FENCE
      break;
    case 5:
      aes_state->key0 = xs1;
      aes_state->key1 = xs2;
      break;
    case 6:
      aes_state->key2 = xs1;
      aes_state->key3 = xs2;
      break;
    case 7:
      aes_state->iv0 = xs1;
      aes_state->iv1 = xs2;
      break;
    case 4:
      aes_state->enc = xs1 != 0;
      break;
    case 1:
      aes_state->ip = xs1;
      aes_state->isize = xs2;
      break;
    case 2:
      // TODO: actually implement, for now this is just memcpy
      //printf("src=0x%lx sz=0x%lx dst=0x%lx cmgflagptr=0x%lx\n", aes_state->ip, aes_state->isize, xs1, xs2);
      aes_state->op = xs1;
      aes_state->cmpflag = xs2;
      while (aes_state->size_processed < aes_state->isize) {
        uint8_t temp = p->get_mmu()->load<uint8_t>(aes_state->ip + aes_state->size_processed);
        p->get_mmu()->store<uint8_t>(aes_state->op + aes_state->size_processed, temp);
        aes_state->size_processed += (aes_state->isize - aes_state->size_processed >= 1 ? 1 : aes_state->isize - aes_state->size_processed);
      }
      break;
    case 3: //Check completion
      p->get_mmu()->store<uint64_t>(aes_state->cmpflag, aes_state->isize == aes_state->size_processed ? 1 : 0);
      //printf("m[cmpflg]=0x%lx\n", aes_state->isize == aes_state->size_processed ? 1 : 0);
      return 1; // dummy
      break;
    default:
      illegal_instruction();
      break;
  }
  return aes_state->isize;
}

void rerocc_cluster_t::write_to_file(char* file_str, reg_t size, reg_t start_ptr) {
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

reg_t rerocc_cluster_t::compress(compress_state_t* compress_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch (insn.funct){
    case 0: // Fence
      break;
    case 5: // hash table size
      compress_state->htsize_log2_snappycomp = xs1;
      break;
    case 4: // history size
      compress_state->hist_snappycomp = xs1;
      break;
//    case 10:
//      latency_snappycomp = xs1; has_intermediate_cache_snappycomp = xs2;
//      break;
    case 1: // src info
      compress_state->ip_snappycomp = xs1; compress_state->isize_snappycomp = xs2;
      break;
    case 2: // dest info
      compress_state->op_snappycomp = xs1; compress_state->cmpflag_snappycomp = xs2;
      printf("DEBUG: Doing snappycompression\n");
      // Just use the snappy binary
      // 1. Load from ip(mmu) and store into a file(file pointer)
      // 2. snappycompress that file(snappy binary) and store to op(mmu)
      write_to_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped", compress_state->isize_snappycomp, compress_state->ip_snappycomp);
      system(STRINGIZE_VALUE_OF(SNAPPY_COMP_BIN) " " STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped");
      {
        printf("DEBUG: Finished doing host snappy\n");
        FILE* file2 = fopen(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped.comp", "r");
        fseek(file2, 0, SEEK_END);
        compress_state->osize = ftell(file2);
        fseek(file2, 0, SEEK_SET);
        compress_state->size_processed = 0;
        while(compress_state->size_processed<compress_state->osize){
          uint8_t temp;
          fread(&temp, sizeof(uint8_t), 1, file2);
          p->get_mmu()->store<uint8_t>(compress_state->op_snappycomp+compress_state->size_processed, temp);
          ++compress_state->size_processed;
          //size_processed += (osize-size_processed>=8 ? 8 : osize-size_processed);
        }
        fclose(file2);
        printf("DEBUG: Wrote data back to memory\n");
      }
      compress_state->size_processed = 0;
      system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped");
      system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped.comp");
      break;
    case 3: // Check snappycompletion
      printf("DEBUG: check snappycompletion 0x%lx\n", compress_state->cmpflag_snappycomp);
      p->get_mmu()->store<uint32_t>(compress_state->cmpflag_snappycomp, 1);
      printf("DEBUG: done with snappycompletion\n");
      //cmpflag = osize; // Return output size
      //cmpflag = (requests_processed==somevalue) ? 1 : 0;
      return compress_state->osize;
      break;

    default:
      illegal_instruction();
      break;
  }
  return 0;
}

reg_t rerocc_cluster_t::decompress(decompress_state_t* decompress_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch (insn.funct){
    case 0: // Fence
      break;

    case 4: // history size
      decompress_state->hist_snappydecomp = xs1;
      break;
//    case 10:
//      latency_snappydecomp = xs1; has_intermediate_cache_snappydecomp = xs2;
//      break;
    case 1: // src info
      decompress_state->ip_snappydecomp = xs1; decompress_state->isize_snappydecomp = xs2;
      break;
    case 2: // dest info
      decompress_state->op_snappydecomp = xs1; decompress_state->cmpflag_snappydecomp = xs2;
      printf("DEBUG: Doing snappydecompression\n");
      // Just use the snappy binary
      // 1. Load from ip(mmu) and store into a file(file pointer)
      // 2. snappydecompress that file(snappy binary) and store to op(mmu)
      write_to_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped", decompress_state->isize_snappydecomp, decompress_state->ip_snappydecomp);
      //system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped");
      system(STRINGIZE_VALUE_OF(SNAPPY_DECOMP_BIN) " " STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped");
      {
        printf("DEBUG: Finished doing host snappy\n");
        FILE* file2 = fopen(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped.uncomp", "r");
        fseek(file2, 0, SEEK_END);
        decompress_state->osize = ftell(file2);
        fseek(file2, 0, SEEK_SET);
        decompress_state->size_processed = 0;
        while(decompress_state->size_processed<decompress_state->osize){
          uint8_t temp;
          fread(&temp, sizeof(uint8_t), 1, file2);
          p->get_mmu()->store<uint8_t>(decompress_state->op_snappydecomp+decompress_state->size_processed, temp);
          ++decompress_state->size_processed;
          //size_processed += (osize-size_processed>=8 ? 8 : osize-size_processed);
        }
        fclose(file2);
        printf("DEBUG: Wrote data back to memory\n");
      }
      decompress_state->size_processed = 0;
      system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped");
      system("rm -rf " STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped.uncomp");
      break;
    case 3: // Check snappydecompletion
      printf("DEBUG: check snappydecompletion 0x%lx\n", decompress_state->cmpflag_snappydecomp);
      p->get_mmu()->store<uint32_t>(decompress_state->cmpflag_snappydecomp, 1);
      printf("DEBUG: done with snappydecompletion\n");
      //cmpflag = osize; // Return output size
      //cmpflag = (requests_processed==somevalue) ? 1 : 0;
      return decompress_state->osize;
      break;

    default:
      illegal_instruction();
      break;
  }
  return 0;
}

reg_t rerocc_cluster_t::dispatch(uint8_t accid, rocc_insn_t insn, reg_t xs1, reg_t xs2) {
  switch (accid) {
    case 0:
      return aes256cbc(&aes_state[0], insn, xs1, xs2);
    case 1:
      return aes256cbc(&aes_state[1], insn, xs1, xs2);
    case 2:
      return memcpy(&memcpy_state[0], insn, xs1, xs2);
    case 3:
      return memcpy(&memcpy_state[1], insn, xs1, xs2);
    case 4:
    case 5:
    case 6:
    case 7:
      printf("Unsupported accid:%d. No proto ser/des implemented.\n", accid);
      illegal_instruction();
    case 8:
      return compress(&compress_state[0], insn, xs1, xs2);
    case 9:
      return decompress(&decompress_state[0], insn, xs1, xs2);
  }
  return 0;
}

define_rerocc_funcs(rerocc_cluster_t, xstr(EXTENSION_NAME), dispatch)

std::vector<insn_desc_t> rerocc_cluster_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_rerocc_insns(insns);
  return insns;
}

std::vector<disasm_insn_t*> rerocc_cluster_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}

// THIS MUST MATCH EXTENSION_NAME
REGISTER_EXTENSION(rerocccluster, []() { return new rerocc_cluster_t; })
