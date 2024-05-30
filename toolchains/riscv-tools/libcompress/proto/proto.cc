#include "proto.h"
#include "primitives_des.pb.h"
#include "primitives_ser.pb.h"

using namespace std;
proto_t::proto_t(){
  //Reset the architectural state
  descriptor_table_ptr=0; dest_base_addr=0;
  base_ptr=0; min_field_no_and_input_length=0;
  fixed_alloc_region_addr=0; array_alloc_region_addr=0;
}

// Proto deserializer: opcode 1, fncode[6] 0
// Proto serializer: opcode 1, fncode[6] 1
reg_t proto_t::custom1(rocc_insn_t insn, reg_t xs1, reg_t UNUSED xs2){
  // Deserializer
  if(insn.funct<64){
    switch(insn.funct){
      case 0: //FENCE: not necessary in spike models
        break;
      case 3: //MEM_SETUP: give alloc-ed region addr
        fixed_alloc_region_addr = xs1; array_alloc_region_addr = xs2;
        break;
      case 1: //PROTO_PARSE_INFO
        descriptor_table_ptr = xs1; dest_base_addr = xs2;
        break;
      case 2: //DO_PROTO_PARSE
        base_ptr = xs1; min_field_no_and_input_length = xs2;
        
        /* Start execution
        google::protobuf::Arena arena;
        primitivetests::Paccint32Message* parseintosaccel[1];
        parseintosaccel[0] = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
        string newstr[1];
        parseintosaccel[0]->ParseFromString(newstr[0]);
        */

        // How about just doing the below?
        {
          primitivetests::Paccint32Message* parseintos = (primitivetests::Paccint32Message*)(dest_base_addr);
          printf("parseintos: %016llx, dest_base_addr: %016llx\n", parseintos, dest_base_addr);
          printf("const char* charptr = (char*)(base_ptr);\n");
          const char* charptr = (char*)(base_ptr);
          printf("charptr: %016llx\n", charptr);
          // string str = (string)(charptr);
          // printf("After string str = (string)(charptr);\n");
          // printf("str: %s\n", str);
          printf("Before parseintos->ParseFromString(charptr);\n");
          parseintos->ParseFromString(charptr);
          printf("After parseintos->ParseFromString(charptr);\n");
        }
        break;
      case 4: //CHECK_COMPLETION: just say it's completed
        return 1;
        break;
      default:
        illegal_instruction();
        break;     
    }
  }
  // Serializer
  else{
    switch(insn.funct % 64){
      case 0: //FENCE
        break;

      default:
        illegal_instruction();
        break;
    }
  }
  return 1;
}

#ifndef TOP
define_custom_func(proto_t, "proto", proto_custom1, custom1)

std::vector<insn_desc_t> proto_t::get_instructions()
{
  std::vector<insn_desc_t> insns;
  push_custom_insn(insns, ROCC_OPCODE1, ROCC_OPCODE_MASK, ILLEGAL_INSN_FUNC, proto_custom1);
  return insns;
}

std::vector<disasm_insn_t*> proto_t::get_disasms()
{
  std::vector<disasm_insn_t*> insns;
  return insns;
}

REGISTER_EXTENSION(proto, []() { return new proto_t; })
#endif

