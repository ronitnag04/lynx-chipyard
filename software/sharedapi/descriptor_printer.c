#include <stdio.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void print_desc_impl(const uint64_t* desc, char* msg, size_t nest_amt) {
  char shift[1024] = {0};
  if (nest_amt > 0) {
    for (size_t i = 0; i < nest_amt - 1; ++i)
      shift[i] = ' ';
    shift[nest_amt] = 0;
  } else {
    shift[0] = 0;
  }
  printf("%sDescPtr:%p MsgPtr:%p\n", shift, desc, msg);
  uint32_t min_field = *(desc + 3) >> 32;
  uint32_t max_field = *(desc + 3) & 0xFFFFFFFF;
  uint64_t hasbits_off = *(desc + 2);
  printf("%sMinF:%lu MaxF:%lu HasBitsOff:%lu\n", shift, min_field, max_field, hasbits_off);

  uint32_t hasbits_size = ((((max_field - min_field) + 1 + 1) + 31) / 32); // +1 +1 since you don't use the 0th bit
  uint32_t* hasbits_ptr = (uint32_t*)(msg + hasbits_off);
  // assuming that 0th bit index is unset (since there can't be field no: 0)
  printf("%s(assumed) HasBitsWordSize: %d\n", shift, hasbits_size);
  for (size_t i = 0; i < hasbits_size; ++i) {
    printf("%s[%lu]=0x%08llx\n", shift, i, *(hasbits_ptr+i));
  }

  size_t entry_off = 0;
  for (size_t i = min_field; i < max_field + 1; ++i) {
    size_t bit_idx = (i - min_field) + 1;
    size_t word_idx = (bit_idx) / 32;
    bool present = ((*(hasbits_ptr + word_idx)) >> bit_idx) & 0x1;

    if (present) {
      bool is_repeated = (*(desc + 4 + entry_off*2) >> 63) & 0x1;
      uint32_t cpp_type = (*(desc + 4 + entry_off*2) >> 58) & 0x1F;
      assert(cpp_type != 0);
      uint64_t offset = (*(desc + 4 + entry_off*2)) & 0x3FFFFFFFFFFFFFF;
      uint64_t nested_msg_desc_ptr = *(desc + 5 + entry_off*2);
      printf("%sF%lu: Rep?:%d Type:%lu OffToF:%lu Ptr:0x%016llx\n", shift, i, is_repeated, cpp_type, offset, nested_msg_desc_ptr);
      if (cpp_type == 11) {
        uint64_t* new_msg_ptr_loc = (uint64_t*)(msg + offset);
        uint64_t  new_msg_ptr = *new_msg_ptr_loc;
        printf("%sNewMsgPtrLoc:%p\n", shift, new_msg_ptr_loc);
        print_desc_impl((const uint64_t*)nested_msg_desc_ptr, (char*)new_msg_ptr, nest_amt + 2);
      }
    }
    ++entry_off;
  }

  printf("%sDone\n", shift);
}
