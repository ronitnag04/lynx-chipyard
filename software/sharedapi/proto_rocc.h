#ifndef PROTO_ROCC_H
#define PROTO_ROCC_H

#if !defined(__x86_64__)

#if defined(USE_PROTO_SER_ACC) || defined(USE_PROTO_DES_ACC)

#define PROTOACC_SER_OPCODE 3
void SerClearAccelTLB(void);
void SerCreateArenas(size_t num_string_pointers, size_t total_string_data_bytes, volatile char*** string_pointer_region_out, volatile char** string_data_region_out);
void SerSetArenaInfoAndClearTLB(volatile char** string_pointer_region, volatile char* string_data_region);
volatile char ** AccelSetupAllocRegionSerializer(size_t num_string_pointers, size_t total_string_data_bytes);
volatile char * BlockOnSerializedValue(volatile char ** ptrs, int index);
size_t GetSerializedLength(volatile char ** ptrs, int index);
void AccelSerializeToString_Helper(const void * descriptor_table_ptr, void * src_base_addr);

#define PROTOACC_OPCODE 2
void DeserClearAccelTLB(void);
void DeserCreateArenas(size_t region_size_bytes, volatile char** fixed_alloc_region_out, volatile char** array_alloc_region_out);
void DeserSetArenaInfoAndClearTLB(volatile char* fixed_alloc_region, volatile char* array_alloc_region);
void AccelSetupFixedAllocRegion(size_t region_size_bytes);
void AccelParseFromString_Helper(const void * descriptor_table_ptr, void * dest_base_addr, const void * base_ptr, size_t input_length);
uint64_t BlockOnDeserialization();

#endif

#endif

#endif // PROTO_ROCC_H
