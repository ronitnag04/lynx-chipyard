#if !defined(__x86_64__)

#if defined(USE_COMPRESS_ACC) || defined(USE_DECOMPRESS_ACC)

#include <stdbool.h>
#include <assert.h>
#include <malloc.h>
#include "rocc.h"
#include "compress_rocc.h"
#include "helpers.h"

#define COMP_EXTEND 0 // for compression. for decompression this is 0

#define accprintf(...) (0)

size_t GetZStdDecompressSize(uint8_t* compressed_data, size_t len){
  #define rshl(x, y) ((x) >> (y))

/* For Snappy */
  // Varint decoding of the first 1-5 bytes
  // Reference: https://protobuf.dev/programming-guides/encoding/
  uint64_t result = 0;
  int shift = 0;
  for(int i=0; i<5; ++i){
    const uint8_t byte_i = compressed_data[i];
    result |= ((uint64_t)(byte_i & 0x7F)) << shift;
    const uint8_t continue_i = (byte_i & 0x80);
    if(!continue_i){
      return result;
    }
    shift += 7;
  }
  return -1; // Error if not returned in the for loop

/* For ZStd
  // Assumption: compressed_data follows the right zstd format. (No format errors)
  // Using: https://github.com/facebook/zstd/blob/dev/doc/zstd_compression_format.md
  // Reference C++: https://github.com/facebook/zstd/blob/dev/doc/educational_decoder/zstd_decompress.c#L555

  size_t frame_content_size;

  //// DEBUG
  //for (size_t i = 0; i < len; i++)
  //  gpr_log(GPR_INFO, "compressed_data[%d]=0x%" PRIx8, i, compressed_data[i]);

  // NOTE: skipping just for speed
  //// Magic Number (4B)
  //assert (((uint32_t*)compressed_data)[0] == 0xFD2FB528);

  // Frame Header (2-14B)
  const uint8_t frame_header_descriptor = compressed_data[4];
  const uint8_t            dict_id_flag = rshl(frame_header_descriptor, 0) & 0x3; // 2b
  const uint8_t   content_checksum_flag = rshl(frame_header_descriptor, 2) & 0x1;
  const uint8_t            reserved_bit = rshl(frame_header_descriptor, 3) & 0x1;
  const uint8_t              unused_bit = rshl(frame_header_descriptor, 4) & 0x1;
  const uint8_t     single_segment_flag = rshl(frame_header_descriptor, 5) & 0x1;
  const uint8_t frame_content_size_flag = rshl(frame_header_descriptor, 6) & 0x3; // 2b

  uint8_t fcs_field_size = 0;
  if(frame_content_size_flag == 0) {
    if (!single_segment_flag) {
      return 0; // frame_content_size is not provided
    } else {
      fcs_field_size = 1;
    }
  } else {
    switch (frame_content_size_flag) {
      case 1:
        fcs_field_size = 2;
        break;
      case 2:
        fcs_field_size = 4;
        break;
      case 3:
        fcs_field_size = 8;
        break;
    }
  }

  const uint8_t window_descriptor_size = !single_segment_flag ? 1 : 0;

  const int size_array[] = {0, 1, 2, 4};
  const uint8_t did_field_size = size_array[dict_id_flag];

  // Below: 4 is the magic number size, and 1 is the frame header descriptor size
	const uint8_t frame_content_size_boffset = 4 + 1 + window_descriptor_size + did_field_size;
  //gpr_log(GPR_INFO, "fcsboff=%d wds=%d dfs=%d", frame_content_size_boffset, window_descriptor_size, did_field_size);

  //for (size_t i = frame_content_size_boffset; i < len - frame_content_size_boffset; i++)
  //  gpr_log(GPR_INFO, "compressed_data[%d]=0x%" PRIx8, i, compressed_data[i]);
  switch (fcs_field_size) {
    case 1:
      frame_content_size = compressed_data[frame_content_size_boffset];
      break;
    case 2:
      frame_content_size = *((uint16_t*)(&compressed_data[frame_content_size_boffset])) + 256;
      break;
    case 4:
      frame_content_size = *((uint32_t*)(&compressed_data[frame_content_size_boffset]));
      break;
    case 8:
      frame_content_size = *((uint64_t*)(&compressed_data[frame_content_size_boffset]));
      break;
  }

  //gpr_log(GPR_INFO, "frame_content_size: %d", frame_content_size);
  return frame_content_size;
*/
}
size_t ZStdCompress(volatile uint8_t* litbuf, size_t litbuf_sz, volatile uint8_t* seqbuf, size_t seqbuf_sz, uint8_t* src, size_t src_sz, uint8_t* dest) {
  bool cmpflag = 0;
  // TODO: Forgot to insert asm volatile fence here
  // Fence
  ROCC_INSTRUCTION(COMP_OPCODE, 0+COMP_EXTEND);
  // Set hash table size
  ROCC_INSTRUCTION_S(COMP_OPCODE, 14, 9+COMP_EXTEND);
  // Set history size
  ROCC_INSTRUCTION_S(COMP_OPCODE, 64UL<<10, 8+COMP_EXTEND);
  // Latency injection
  ROCC_INSTRUCTION_SS(COMP_OPCODE, 0L, false, 10+COMP_EXTEND);
  // Source info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, src, src_sz, 1+COMP_EXTEND);
  // Literal/Sequence buffer info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, litbuf, litbuf_sz, 2+COMP_EXTEND);
  ROCC_INSTRUCTION_SS(COMP_OPCODE, seqbuf, seqbuf_sz, 3+COMP_EXTEND);
  // Destination info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, dest, cmpflag, 4+COMP_EXTEND);
  // Compression level: 3 here
  ROCC_INSTRUCTION_S(COMP_OPCODE, 3, 5+COMP_EXTEND);
  // Check completion & Get compressed file size
  size_t out_size;
  ROCC_INSTRUCTION_D(COMP_OPCODE, out_size, 11+COMP_EXTEND);
  return out_size;
}
size_t SnappyCompress(uint8_t* src, size_t src_sz, uint8_t* dest) {
  bool cmpflag = 0;
  // Fence -> Allocate write region (dest)
  ROCC_INSTRUCTION(COMP_OPCODE, 0);//0
  // Set hash table size: pick from 9 to 14
  ROCC_INSTRUCTION_S(COMP_OPCODE, 14, 5);//5
  // Set history size: pick from 2<<10 to 64<<10 
  ROCC_INSTRUCTION_S(COMP_OPCODE, 64UL<<10, 4);//4
  // Source info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, (uint64_t)src, (uint64_t)src_sz, 1);//1
  // Destination info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, (uint64_t)dest, (uint64_t)cmpflag, 2);//2
  size_t out_size;
  ROCC_INSTRUCTION_D(COMP_OPCODE, out_size, 3);//3
  // TODO: Snappy compressor should give the output size -- spike=OK, RTL=?
  return out_size;
}

// TODO: workspace size is unknown? seems wonky?
size_t ZStdDecompress(volatile uint8_t* workspace, uint8_t* src, size_t src_sz, uint8_t* dest) {
  bool cmpflag = 0;
  // Fence
  // TODO: forgot to insert asm volatile fence here
  ROCC_INSTRUCTION(COMP_OPCODE, 0);
  // Set history size
  ROCC_INSTRUCTION_S(COMP_OPCODE, 65536, 7);
  // Set result area and workspace area
  // Latency injection
  ROCC_INSTRUCTION_S(COMP_OPCODE, 0, 2);
  // Set algorithm
  ROCC_INSTRUCTION_S(COMP_OPCODE, 0, 1);
  // Input info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, src, src_sz, 3);
  // Workspace info
  ROCC_INSTRUCTION_S(COMP_OPCODE, workspace, 4);
  // Output info
  ROCC_INSTRUCTION_SS(COMP_OPCODE, dest, cmpflag, 5);
  // Check completion
  size_t retval;
  ROCC_INSTRUCTION_D(COMP_OPCODE, retval, 6);
}
size_t SnappyDecompress(uint8_t* src, size_t src_sz, uint8_t* dest) {
  // SnappyDecompressAccelSetup
  ROCC_INSTRUCTION(DECOMP_OPCODE, 0);//0
  // DecompressSetDynamicHistSize
  ROCC_INSTRUCTION_S(DECOMP_OPCODE, 64UL<<10, 4);//4
  // SnappyAccelRawUncompress(comp data, comp len, write region)
  bool completion_flag = false;
  ROCC_INSTRUCTION_SS(DECOMP_OPCODE, (uint64_t)src, (uint64_t)src_sz, 1);//1
  ROCC_INSTRUCTION_SS(DECOMP_OPCODE, (uint64_t)dest, (uint64_t)completion_flag, 2);//2
  uint64_t retval;
  ROCC_INSTRUCTION_D(DECOMP_OPCODE, retval, 3);//3
  /*
  asm volatile ("fence");
  while (! *(completion_flag)) {
    asm volatile ("fence");
  }
  return *completion_flag;
  */
  return 0;
}
#define PAGESIZE_BYTES 4096
unsigned char * SnappySetupAllocRegion(size_t write_region_size) {            
    size_t regionsize = sizeof(char) * (write_region_size);                                                          
    //size_t regionsize = sizeof(unsigned char) * (PAGESIZE_BYTES);                                                  
                                                                                                                     
    unsigned char * fixed_alloc_region = (unsigned char*)memalign(PAGESIZE_BYTES, regionsize);                       
    for (uint64_t i = 0; i < regionsize; i += PAGESIZE_BYTES) {                                                      
        fixed_alloc_region[i] = 0;                                                                                   
    }                                                                                                                
                                                                                                                     
    uint64_t fixed_ptr_as_int = (uint64_t)fixed_alloc_region;                                                        
    assert((fixed_ptr_as_int & 0x7) == 0x0);                                                                         

    return fixed_alloc_region;                                                                                       
}   

#endif

#endif
