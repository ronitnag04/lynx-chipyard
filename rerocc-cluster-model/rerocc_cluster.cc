#include "rerocc_cluster.h"

#include <riscv/mmu.h>
#include <riscv/rerocc.h>

#define printf(...) (0)

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
  printf("DEBUG: " STRINGIZE_VALUE_OF(OPENSSL_BIN) "\n");
}

static void run_command(char* cmd) {
  printf("Running command: \"%s\"\n", cmd);
  int r = system(cmd);
  if (r) {
    printf("Failed: \"%s\". Exiting.\n", cmd);
    exit(1);
  }
}

static void rm(char* file) {
  char buffer[1024];
  snprintf(buffer, 1024, "rm -rf %s", file);
  run_command(buffer);
}

void rerocc_cluster_t::write_to_file(char* dstfile, reg_t srcptr, reg_t size) {
  rm(dstfile);
  printf("DEBUG: Writing %ld bytes to file\n", size);
  FILE* file = fopen(dstfile, "w");
  assert(file != NULL);
  for (size_t i = 0; i < size; ++i) {
    uint8_t temp = p->get_mmu()->load<uint8_t>(srcptr + i);
    fwrite(&temp, sizeof(uint8_t), 1, file);
  }
  fclose(file);
}

size_t rerocc_cluster_t::write_from_file(char* srcfile, reg_t destptr) {
  FILE* file = fopen(srcfile, "r");
  assert(file != NULL);
  fseek(file, 0, SEEK_END);
  size_t file_bytes = ftell(file);
  fseek(file, 0, SEEK_SET);
  for (size_t i = 0; i < file_bytes; ++i) {
    uint8_t temp;
    fread(&temp, sizeof(uint8_t), 1, file);
    p->get_mmu()->store<uint8_t>(destptr + i, temp);
  }
  fclose(file);
  printf("DEBUG: Read %ld bytes from file\n", file_bytes);
  return file_bytes;
}

reg_t rerocc_cluster_t::memcpy(memcpy_state_t* memcpy_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch(insn.funct){
    case 0:
      break;
    case 1:
      memcpy_state->ip = xs1;
      memcpy_state->isize = xs2;
      break;
    case 2:
      memcpy_state->op = xs1;
      memcpy_state->cmpflagp = xs2;
      printf("src=0x%lx sz=0x%lx dst=0x%lx cmgflagptr=0x%lx\n", memcpy_state->ip, memcpy_state->isize, memcpy_state->op, memcpy_state->cmpflagp);
      for (size_t i = 0; i < memcpy_state->isize; ++i) {
        p->get_mmu()->store<uint8_t>(memcpy_state->op + i, p->get_mmu()->load<uint8_t>(memcpy_state->ip + i));
      }
      break;
    case 3:
      p->get_mmu()->store<compflag_t>(memcpy_state->cmpflagp, 1);
      break;
    default:
      illegal_instruction();
      break;
  }
  return SUCCESS;
}

static uint64_t reverse_bytes(uint64_t bytes) {
  uint64_t aux = 0;
  for (size_t i = 0; i < 8; ++i) {
    uint64_t byte = (bytes >> i*8) & 0xFF;
    aux |= byte << (64 - 8 - i*8);
  }
  return aux;
}

reg_t rerocc_cluster_t::aescbc(uint8_t accid, aes_state_t* aes_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  char ibuf[1024] = {0};
  char obuf[1024] = {0};
  char ebuf[1024] = {0};
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
      aes_state->enc = (xs1 != 0);
      break;
    case 1:
      aes_state->ip = xs1;
      aes_state->isize = xs2;
      break;
    case 2:
      aes_state->op = xs1;
      aes_state->cmpflagp = xs2;
      printf("src=0x%lx sz=0x%lx dst=0x%lx cmgflagptr=0x%lx\n", aes_state->ip, aes_state->isize, aes_state->op, aes_state->cmpflagp);

      // create unique files for i/o
      snprintf(ibuf, 1024, STRINGIZE_VALUE_OF(CUR_DIR) "/encdec_input%d", accid);
      snprintf(obuf, 1024, STRINGIZE_VALUE_OF(CUR_DIR) "/encdec_input%d_out", accid);
      write_to_file(ibuf, aes_state->ip, aes_state->isize);

      // NOTE: RTL key = (xs1, xs2, (xs1, xs2)) = (key2, key3, (key0, key1))
      // NOTE: RTL iv = (xs1, xs2) = (iv0, iv1)

      // defaulting to AES128 CBC
      // openssl cli uses big endian so reverse the bytes
      snprintf(ebuf, 1024, STRINGIZE_VALUE_OF(OPENSSL_BIN) " enc -aes-128-cbc -nosalt -nopad %s -in %s -out %s -K '%016lx%016lx' -iv '%016lx%016lx'",
         aes_state->enc ? "-e" : "-d",
         ibuf,
         obuf,
         reverse_bytes(aes_state->key0),
         reverse_bytes(aes_state->key1),
         reverse_bytes(aes_state->iv0),
         reverse_bytes(aes_state->iv1)
      );
      run_command(ebuf);

      write_from_file(obuf, aes_state->op);

      rm(ibuf);
      rm(obuf);
      break;
    case 3:
      p->get_mmu()->store<compflag_t>(aes_state->cmpflagp, 1);
      break;
    default:
      illegal_instruction();
      break;
  }
  return SUCCESS;
}

reg_t rerocc_cluster_t::compress(compress_state_t* compress_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch (insn.funct){
    case 0: // Fence
      break;
    case 5: // hash table size
      break;
    case 4: // history size
      break;
    case 1: // src info
      compress_state->ip = xs1; compress_state->isize = xs2;
      break;
    case 2: // dest info
      compress_state->op = xs1; compress_state->cmpflagp = xs2;
      printf("DEBUG: Doing snappycompression\n");
      // Just use the snappy binary
      // 1. Load from ip(mmu) and store into a file(file pointer)
      // 2. snappycompress that file(snappy binary) and store to op(mmu)
      write_to_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped", compress_state->ip, compress_state->isize);
      run_command(STRINGIZE_VALUE_OF(SNAPPY_COMP_BIN) " " STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped");
      compress_state->osize = write_from_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped.comp", compress_state->op);
      rm(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped");
      rm(STRINGIZE_VALUE_OF(CUR_DIR) "/snappydecomped.comp");
      break;
    case 3: // Check snappycompletion
      printf("DEBUG: check snappycompletion 0x%lx\n", compress_state->cmpflagp);
      p->get_mmu()->store<compflag_t>(compress_state->cmpflagp, compress_state->osize);
      printf("DEBUG: done with snappycompletion\n");
      break;

    default:
      illegal_instruction();
      break;
  }
  return SUCCESS;
}

reg_t rerocc_cluster_t::decompress(decompress_state_t* decompress_state, rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  switch (insn.funct){
    case 0: // Fence
      break;
    case 4: // history size
      break;
    case 1: // src info
      decompress_state->ip = xs1; decompress_state->isize = xs2;
      break;
    case 2: // dest info
      decompress_state->op = xs1; decompress_state->cmpflagp = xs2;
      printf("DEBUG: Doing snappydecompression\n");
      // Just use the snappy binary
      // 1. Load from ip(mmu) and store into a file(file pointer)
      // 2. snappydecompress that file(snappy binary) and store to op(mmu)
      write_to_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped", decompress_state->isize, decompress_state->ip);
      run_command(STRINGIZE_VALUE_OF(SNAPPY_DECOMP_BIN) " " STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped");
      decompress_state->osize = write_from_file(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped.uncomp", decompress_state->op);
      rm(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped");
      rm(STRINGIZE_VALUE_OF(CUR_DIR) "/snappycomped.uncomp");
      break;
    case 3: // Check snappydecompletion
      printf("DEBUG: check snappydecompletion 0x%lx\n", decompress_state->cmpflagp);
      p->get_mmu()->store<compflag_t>(decompress_state->cmpflagp, decompress_state->osize);
      printf("DEBUG: done with snappydecompletion\n");
      break;
    default:
      illegal_instruction();
      break;
  }
  return SUCCESS;
}

// todo: technically this should also be bounded by opcode
reg_t rerocc_cluster_t::dispatch(uint8_t accid, rocc_insn_t insn, reg_t xs1, reg_t xs2) {
  // switch (accid) {
  //   case 0:
  //     return aescbc(accid, &aes_state[0], insn, xs1, xs2);
  //   case 1:
  //     return aescbc(accid, &aes_state[1], insn, xs1, xs2);
  //   case 2:
  //     return memcpy(&memcpy_state[0], insn, xs1, xs2);
  //   case 3:
  //     return memcpy(&memcpy_state[1], insn, xs1, xs2);
  //   case 4:
  //   case 5:
  //   case 6:
  //   case 7:
  //     printf("Unsupported accid:%d. No proto ser/des implemented.\n", accid);
  //     illegal_instruction();
  //   case 8:
  //     return compress(&compress_state[0], insn, xs1, xs2);
  //   case 9:
  //     return decompress(&decompress_state[0], insn, xs1, xs2);
  // }
  // return 0;
  return compress(&compress_state[0], insn, xs1, xs2);
}

define_rerocc_funcs(rerocc_cluster_t, STRINGIZE_VALUE_OF(EXTENSION_NAME), dispatch)

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
