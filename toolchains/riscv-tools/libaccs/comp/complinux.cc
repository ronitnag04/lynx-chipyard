#include "comp.h"
using namespace std;
comp_t::comp_t(){
  algorithm = -1; latency = 0;
  ip = 0; isize = 0; wksp = 0; op = 0; cmpflag = 0;
  hist_sram_size = 0;

  size_processed = 0;
}

reg_t comp_t::custom0(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  // Decompressor functions
  if(insn.funct < 64){
    switch (insn.funct){
      case 0: // Fence
        break;
      // Zstd functions
      case 1: // Algorithm
        algorithm = xs1;
        break;
      case 2: // Latency
        latency = xs1;
        break;
      case 3: // ip, isize
        ip = xs1; isize = xs2;
        break;
      case 4: // wksp
        wksp = xs1;
        break;
      case 5: // op, success flag
        op = xs1; cmpflag = xs2;
        // Just use the zstd binary
        // instead of using comp_t::decompress(ip, isize, wksp, op);.
        // 1. Load from ip(mmu) and store into a file(file pointer)
        // 2. Decompress that file(zstd binary) and store to op(mmu)
        {
          FILE* file = fopen("/root/grpc/comped", "w");
          while(size_processed<isize){
            uint8_t temp = p->get_mmu()->load<uint8_t>(ip+size_processed);
            if(file!=NULL){
              fwrite(&temp, sizeof(uint8_t), 1, file);
            }
            ++size_processed;
            //size_processed += (isize-size_processed>=8 ? 8 : isize-size_processed);
          }
          fclose(file);
        }
        system("rm /scratch/junsun/decomped");
        system("/scratch/junsun/zstd/zstd -d /scratch/junsun/comped -o /scratch/junsun/decomped");
        {
          FILE* file2 = fopen("/scratch/junsun/decomped", "r");
          fseek(file2, 0, SEEK_END);
          osize = ftell(file2);
          fseek(file2, 0, SEEK_SET);
          size_processed = 0;
          while(size_processed<osize){
            uint8_t temp;
            fread(&temp, sizeof(uint8_t), 1, file2);
            p->get_mmu()->store<uint8_t>(op+size_processed, temp);
            ++size_processed;
            //size_processed += (osize-size_processed>=8 ? 8 : osize-size_processed);
          } 
          fclose(file2);
        }
        size_processed = 0;
        break;
      case 6: // Check completion
        cmpflag = 1;
        //cmpflag = (requests_processed==somevalue) ? 1 : 0;
        return cmpflag;
        break;
      case 7: // Set history SRAM size
        hist_sram_size = xs1;
        break;


      // Snappy functions
      case 8: // ip, isize
        ip = xs1; isize = xs2;
        break;
      case 9: // op, success_flag
        op = xs1; cmpflag = xs2;
        //TODO: Insert snappy operation
        break;
      case 10: // Check completion
        cmpflag = 1;
        //cmpflag = (requests_processed==somevalue) ? 1 : 0;
        return cmpflag; 
      case 11: // Set history SRAM size, same as 7
        hist_sram_size = xs1;
        break;

      default:
        illegal_instruction();
        break;
    }
  }

  // Compressor functions
  else{
    switch (insn.funct%64){
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
        // Just use the zstd binary
        // 1. Load from ip(mmu) and store into a file(file pointer)
        // 2. Compress that file(zstd binary) and store to op(mmu)
        {
          FILE* file = fopen("/scratch/junsun/decomped", "w");
          while(size_processed<isize_comp){
            uint8_t temp = p->get_mmu()->load<uint8_t>(ip_comp+size_processed);
            if(file!=NULL){
              fwrite(&temp, sizeof(uint8_t), 1, file);
            }
            ++size_processed;
            //size_processed += (isize-size_processed>=8 ? 8 : isize-size_processed);
          }
          fclose(file);
        }
        system("rm /scratch/junsun/comped");
        system("/scratch/junsun/zstd/zstd /scratch/junsun/decomped -o /scratch/junsun/comped");
        {
          FILE* file2 = fopen("/scratch/junsun/comped", "r");
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
        }
        size_processed = 0;
        break;
      case 11: // Check completion
        cmpflag = osize; // Return output size
        //cmpflag = (requests_processed==somevalue) ? 1 : 0;
        return cmpflag;
        break;

      // Snappy functions
      case 6:
        ip_comp = xs1; isize_comp = xs2;
        break;
      case 7:
        op_comp = xs1; cmpflag = xs2;
        //TODO: invoke snappy
        break;

      default:
        illegal_instruction();
        break;
    }
  }  
  return 0;
}


#ifndef TOP
define_custom_func(comp_t, "comp", comp_custom0, custom0)

std::vector<insn_desc_t> comp_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_custom_insn(insns, ROCC_OPCODE0, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, comp_custom0);
  return insns;
}

std::vector<disasm_insn_t*> comp_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}
REGISTER_EXTENSION(comp, []() { return new comp_t; })
#endif
/*
int comp_t::decompress(uint64_t ip, uint64_t isize, uint64_t wksp, uint64_t op){
  uint64_t ptr = ip; // Pointer to the source file. Start from ip.

  // Decompress frame header
  // 1. First 4B should be 0xFD2FB528
  uint32_t magic_no = p->get_mmu()->load<uint32_t>(ip);
  if(magic_no != 0xfd2fb528){
    illegal_instruction();
    return 0;
  }
  ptr += 4;
  // 2. Frame header descriptor (1B).
  uint8_t fhd = p->get_mmu()->load<uint8_t>(ptr);
  ptr += 1;
*/
  /* fhd[7:6]: frame content size flag
  ** fhd[5]: single segment flag --> If not set, window descriptor is 1B
  ** fhd[4]: unused bit
  ** fhd[3]: reversed bit
  ** fhd[2]: content checksum flag --> Final 0~4B will be checksum
  ** fhd[1:0]: dictionary id flag --> Tells dictionary field's size
  */
  // 3. Window descriptor (1B, optional)
  //if(!single_segment) ptr += 1;
  // 4. Dictionary ID (0~4B, optional)
  //ptr += did_size;
  // 5. Frame content size (0~8B, optional)
  //ptr += fcs_size;

  // Decompress block
  // 1. Block header: 3B
  /* bh[0]: last block
  ** bh[2:1]: block type
  ** bh[23:3]: block size
  */
  // 2. Rest is the block content. It consists of literals section and sequences section.
  
  // Decompress literals section

  // Decompress sequences section
//}

