#ifndef COMPRESS_ROCC_H
#define COMPRESS_ROCC_H

#if !defined(__x86_64__)

#include <stdbool.h>
#include <malloc.h>
#include <inttypes.h>
#include <assert.h>

#define PAGESIZE_BYTES 4096
#define COMP_OPCODE 2
#define COMP_EXTEND 0 // for compression. for decompression this is 0

size_t GetZStdDecompressSize(uint8_t* compressed_data, size_t len){
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
  #define rshl(x, y) ((x) >> (y))
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

  const uint8_t frame_content_size_boffset = 4 /* Magic Number */ + 1 /* Frame Header Descriptor */ + window_descriptor_size + did_field_size;
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
}

unsigned char* MemSetup(size_t write_region_size){
  auto regionsize = sizeof(char) * (write_region_size);
  unsigned char* fixed_alloc_region = (unsigned char*)memalign(PAGESIZE_BYTES, regionsize);
  //for (auto i = 0; i < regionsize; i += PAGESIZE_BYTES) {
  //  fixed_alloc_region[i] = 0;
  //}
  uint64_t fixed_ptr_as_int = (uint64_t)fixed_alloc_region;
  assert((fixed_ptr_as_int & 0x7) == 0x0);
  gpr_log(GPR_INFO, "constructed %" PRIu64 " byte region, starting at 0x%016" PRIx64 ", paged-in, for accel",
    (uint64_t)regionsize, fixed_ptr_as_int);
  return fixed_alloc_region;
};

#endif

#endif // COMPRESS_ROCC_H
