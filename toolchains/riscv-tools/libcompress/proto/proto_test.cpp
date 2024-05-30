#include "primitives_des.pb.h"
#include "accellib.h"
#include "rocc.h"
#include "encoding.h"

#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>
#include <cinttypes>
#include <chrono>

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <malloc.h>
#include <inttypes.h>

#define PAGESIZE_BYTES 4096
using namespace std;

// For compile: riscv-unknown-elf-g++ proto_test.c
int main(){
  GOOGLE_PROTOBUF_VERIFY_VERSION;

  printf("Memory region setup\n");
	printf("Fn 0: Fence\n");
	ROCC_INSTRUCTION(PROTOACC_OPCODE, FUNCT_SFENCE+DES_EXTEND);
	size_t regionsize = sizeof(char) * (128 << 13);
  char * fixed_alloc_region = (char*)memalign(PAGESIZE_BYTES, regionsize);
  for (uint64_t i = 0; i < regionsize; i += PAGESIZE_BYTES) {
    fixed_alloc_region[i] = 0;
  }

  char * array_alloc_region = (char*)memalign(PAGESIZE_BYTES, regionsize);
  for (uint64_t i = 0; i < regionsize; i += PAGESIZE_BYTES) {
    array_alloc_region[i] = 0;
  }

  uint64_t fixed_ptr_as_int = (uint64_t)fixed_alloc_region;
  uint64_t array_ptr_as_int = (uint64_t)array_alloc_region;
	printf("Fn 3: Mem Setup\n");
  ROCC_INSTRUCTION_SS(PROTOACC_OPCODE, fixed_ptr_as_int, array_ptr_as_int, FUNCT_MEM_SETUP+DES_EXTEND);
	assert((fixed_ptr_as_int & 0x7) == 0x0);
  assert((array_ptr_as_int & 0x7) == 0x0);

	////////// Serialize to string, use that for deserializer test data //////////
  printf("Serialize to string (CPU)\n");
  #define NUMTESTVALS 1
  int32_t testvals[NUMTESTVALS] = {  1 };
  google::protobuf::Arena arena;
  primitivetests::Paccint32Message* fillmessage = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
  fillmessage->set_paccint32_0(testvals[0]);

  string outstr;
  fillmessage->SerializeToString(&outstr);

  #define ITERS 1
  bool failcheck = false;

  primitivetests::Paccint32Message* parseintos[ITERS];
  for (int q = 0; q < ITERS; q++) {
      parseintos[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
  }

  string newstr[ITERS];
  for (int q = 0; q < ITERS; q++) {
      newstr[q] = outstr;
  }
  ////////// Deserialization on the accelerator start //////////
  printf("Deserialize on the accelerator\n");
  for (int q = 0; q < ITERS; q++) {
    printf("c_str address: %016llx, str: %s\n", newstr[q].c_str(), newstr[q]);
    AccelParseFromString(primitivetests, Paccint32Message, parseintos[q], newstr[q]);
  }
  printf("Block on Completion\n");
  block_on_completion();
  printf("Fail check\n");
  if ( (parseintos[ITERS-1]->paccint32_0() != fillmessage->paccint32_0())  ) {
      failcheck = true;
  }

  if (failcheck) {
      std::cout << "FAIL WRITE NOT IMMEDIATELY VISIBILE OR INCORRECT.\n" << std::flush;
  }

  for (int q = 0; q < ITERS; q++) {
      if (parseintos[q]->paccint32_0() != fillmessage->paccint32_0()) {
          std::cout << "ACCEL FAILED ITER " << q << " ON int32 TEST!\n" << std::flush;
          exit(1);
      }
      if (!(parseintos[q]->has_paccint32_0())) {
          std::cout << "ACCEL FAILED hasbits ITER " << q << " ON int32 TEST!\n" << std::flush;
          exit(1);
      }
  }

  ////////// Produce comparison data //////////
  printf("Produce comparison data (CPU)\n");
  primitivetests::Paccint32Message* parseintoscpu[ITERS];

  for (int q = 0; q < ITERS; q++) {
      parseintoscpu[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
  }

  for (int i = 0; i < ITERS; i++) {
      parseintoscpu[i]->ParseFromString(newstr[i]);
  }

  if (fillmessage->paccint32_0() != parseintoscpu[ITERS-1]->paccint32_0()) {
      printf("FAILED int32 test.\n");
      exit(1);
  } else if (!(parseintoscpu[ITERS-1]->has_paccint32_0())) {
      printf("FAILED hasbits for int32 test.\n");
      exit(1);
  } else {
      printf("PASSED int32 test.\n");
  }

  ////////// End test //////////
  google::protobuf::ShutdownProtobufLibrary();
  return 0;

}
