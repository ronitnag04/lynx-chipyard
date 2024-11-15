#ifndef _REROCC_CLUSTER_H
#define _REROCC_CLUSTER_H

#include <vector>
#include <riscv/decode.h>
#include <riscv/rocc.h>

#define SUCCESS 1
typedef uint64_t compflag_t;

typedef struct {
  reg_t ip;
  reg_t isize;
  reg_t op;
  reg_t cmpflagp;
} memcpy_state_t;

typedef struct {
  reg_t key0;
  reg_t key1;
  reg_t key2;
  reg_t key3;
  reg_t iv0;
  reg_t iv1;
  bool enc;
  reg_t ip;
  reg_t isize;
  reg_t op;
  reg_t cmpflagp;
} aes_state_t;

typedef struct {
  reg_t cmpflagp; // snappycompletion flag

  // Doesn't exist in the accelerator architecture, but needed for C model
  uint64_t osize;

  // snappycompressor
  reg_t ip, isize;
  reg_t op;
} compress_state_t;

typedef struct {
  reg_t cmpflagp; // snappydecompletion flag

  // Doesn't exist in the accelerator architecture, but needed for C model
  uint64_t osize;

  // snappydecompressor
  reg_t ip, isize;
  reg_t op;
} decompress_state_t;

#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

class rerocc_cluster_t : public extension_t {
public:
  const char* name() { return STRINGIZE_VALUE_OF(EXTENSION_NAME); }
  rerocc_cluster_t();

  reg_t dispatch(uint8_t accid, rocc_insn_t insn, reg_t xs1, reg_t xs2);

  virtual std::vector<insn_desc_t> get_instructions();
  virtual std::vector<disasm_insn_t*> get_disasms();

private:
  reg_t memcpy(memcpy_state_t* memcpy_state, rocc_insn_t insn, reg_t xs1, reg_t xs2);
  memcpy_state_t memcpy_state[2];
  reg_t aescbc(uint8_t accid, aes_state_t* aes_state, rocc_insn_t insn, reg_t xs1, reg_t xs2);
  aes_state_t aes_state[2];
  reg_t compress(compress_state_t* compress_state, rocc_insn_t insn, reg_t xs1, reg_t xs2);
  compress_state_t compress_state[1];
  reg_t decompress(decompress_state_t* decompress_state, rocc_insn_t insn, reg_t xs1, reg_t xs2);
  decompress_state_t decompress_state[1];

  void write_to_file(char* dstfile, reg_t srcptr, reg_t size);
  size_t write_from_file(char* srcfile, reg_t destptr);
};

#endif
