#include "protolib.pb.h"

#define ACCEL_DESC(filename, msgtype) filename##_FriendStruct_##msgtype##_ACCEL_DESCRIPTORS::msgtype##_ACCEL_DESCRIPTORS
#define CREATE_MSG_PTR(filename, msgtype) \
  filename::msgtype* msg = google::protobuf::Arena::CreateMessage<filename::msgtype>(&arena); \
  const uint64_t* desc = ACCEL_DESC(filename, msgtype)

void print_desc(const uint64_t* desc, char* msg, size_t nest_amt) {
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
  uint32_t* hasbits_ptr = reinterpret_cast<uint32_t*>(msg + hasbits_off);
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
        print_desc((const uint64_t*)nested_msg_desc_ptr, (char*)new_msg_ptr, nest_amt + 2);
      }
    }
    ++entry_off;
  }

  printf("%sDone\n", shift);
}

#define CREATE_SET_5(filename, innermsgtype) \
  { \
  CREATE_MSG_PTR(filename, Paccser_##innermsgtype##Message); \
  msg->set_pacc##innermsgtype##_0(1); \
  msg->set_pacc##innermsgtype##_1(1); \
  msg->set_pacc##innermsgtype##_2(1); \
  msg->set_pacc##innermsgtype##_3(1); \
  msg->set_pacc##innermsgtype##_4(1); \
  print_desc(desc, reinterpret_cast<char*>(msg)); \
  }

void fleetbench_rpc_P2_request_Message1_Set_3(protolib::fleetbench_rpc_P2_request_Message1* message, std::string* s) {
  fprintf(stderr, "Setting message->f_5,4\n");
  message->set_f_5(s->substr(0, 20));
  message->set_f_4(0xa9585331a23920);
  fprintf(stderr, "Setting message->f_33\n");
  protolib::fleetbench_rpc_P2_request_Message1::M3* v0 = message->mutable_f_33();
  fprintf(stderr, "Setting f_33->f_0\n");
  v0->set_f_0(0x72761ab863bb6e);
  fprintf(stderr, "Setting f_33->f_21\n");
  protolib::fleetbench_rpc_P2_request_Message1::M3::M6* v1 = v0->mutable_f_21();
  fprintf(stderr, "Setting f_21->f_6,7,5,4,1,2,3\n");
  v1->set_f_6(0x1f);
  v1->set_f_7(s->substr(20, 21));
  v1->set_f_5(0x3d17092f0cbe81);
  v1->set_f_4(0x54387427537d543c);
  v1->set_f_1(protolib::fleetbench_rpc_P2_request_Message1::M3::M6::E2_CONST_5);
  v1->set_f_2(0x3a738c2a);
  v1->set_f_3(0x3eb176daced0d206);
  // v1->set_f_9(0x1);
  // v1->add_f_0("!@#");
  fprintf(stderr, "Setting f_33->f_3,5\n");
  v0->set_f_3(0x8);
  v0->set_f_5(0x413273d3ea0d87c8);
  fprintf(stderr, "Setting message->f_20\n");
  protolib::fleetbench_rpc_P2_request_Message1::M1* v2 = message->mutable_f_20();
  fprintf(stderr, "Setting f_20->f_1,0\n");
  v2->add_f_1(0xe9c9fd2);
  v2->set_f_0(0xe574ad1e931e);
  fprintf(stderr, "Setting message->f_36\n");
  protolib::fleetbench_rpc_P2_request_Message1::M4* v3 = message->mutable_f_36();
  fprintf(stderr, "Setting f_36->f_5,3,2,4,0,6,7\n");
  v3->set_f_5(s->substr(21, 45));
  v3->set_f_3(0xf);
  v3->set_f_2(s->substr(45, 76));
  v3->set_f_4(0x14);
  v3->set_f_0(0x25a1606a);
  v3->set_f_6(0x57);
  v3->set_f_7(0xd27fffeee10149);
}

int main(int argc, char** argv) {
  GOOGLE_PROTOBUF_VERIFY_VERSION;
  google::protobuf::Arena arena;

  std::string s(1024, 'a');
  CREATE_MSG_PTR(protolib, RequestMessage);
  protolib::P2RequestMessage* msginner = msg->mutable_p2();
  fleetbench_rpc_P2_request_Message1_Set_3(msginner->mutable_m_1(), &s);
  print_desc(desc, reinterpret_cast<char*>(msg), 0);
  // CREATE_MSG_PTR(protolib, TestingHasBitsMessage);
  // msg->set_first(false);
  // msg->set_last(false);
  // print_desc(desc, reinterpret_cast<char*>(msg), 0);

  // CREATE_SET_5(protolib, bool);
  // CREATE_SET_5(protolib, double);
  // CREATE_SET_5(protolib, fixed32);
  // CREATE_SET_5(protolib, fixed64);
  // CREATE_SET_5(protolib, float);
  // CREATE_SET_5(protolib, sfixed32);
  // CREATE_SET_5(protolib, sfixed64);
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_bool_repeatedMessage);
  // msg->add_paccbool_repeated_0(false);
  // msg->add_paccbool_repeated_0(false);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_double_repeatedMessage);
  // msg->add_paccdouble_repeated_0(1.0);
  // msg->add_paccdouble_repeated_0(1.0);
  // msg->add_paccdouble_repeated_0(1.0);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_float_repeatedMessage);
  // msg->add_paccfloat_repeated_0(1.0);
  // msg->add_paccfloat_repeated_0(1.0);
  // msg->add_paccfloat_repeated_0(1.0);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_bytesMessage);
  // msg->set_paccbytes_0("0123");
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_bytes_repeatedMessage);
  // msg->add_paccbytes_repeated_0("0123");
  // msg->add_paccbytes_repeated_0("4567");
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_stringMessage);
  // msg->set_paccstring_0("0123");
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // CREATE_SET_5(protolib, uint64);
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_uint64_repeatedMessage);
  // msg->add_paccuint64_repeated_0(1);
  // msg->add_paccuint64_repeated_0(1);
  // msg->add_paccuint64_repeated_0(1);
  // msg->add_paccuint64_repeated_1(1);
  // msg->add_paccuint64_repeated_1(1);
  // msg->add_paccuint64_repeated_1(1);
  // msg->add_paccuint64_repeated_2(1);
  // msg->add_paccuint64_repeated_2(1);
  // msg->add_paccuint64_repeated_2(1);
  // msg->add_paccuint64_repeated_3(1);
  // msg->add_paccuint64_repeated_3(1);
  // msg->add_paccuint64_repeated_3(1);
  // msg->add_paccuint64_repeated_4(1);
  // msg->add_paccuint64_repeated_4(1);
  // msg->add_paccuint64_repeated_4(1);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_uint64_64Message);
  // msg->set_paccuint64_0(1);
  // msg->set_paccuint64_1(1);
  // msg->set_paccuint64_2(1);
  // msg->set_paccuint64_3(1);
  // msg->set_paccuint64_4(1);
  // msg->set_paccuint64_5(1);
  // msg->set_paccuint64_6(1);
  // msg->set_paccuint64_7(1);
  // msg->set_paccuint64_8(1);
  // msg->set_paccuint64_9(1);
  // msg->set_paccuint64_10(1);
  // msg->set_paccuint64_11(1);
  // msg->set_paccuint64_12(1);
  // msg->set_paccuint64_13(1);
  // msg->set_paccuint64_14(1);
  // msg->set_paccuint64_15(1);
  // msg->set_paccuint64_16(1);
  // msg->set_paccuint64_17(1);
  // msg->set_paccuint64_18(1);
  // msg->set_paccuint64_19(1);
  // msg->set_paccuint64_20(1);
  // msg->set_paccuint64_21(1);
  // msg->set_paccuint64_22(1);
  // msg->set_paccuint64_23(1);
  // msg->set_paccuint64_24(1);
  // msg->set_paccuint64_25(1);
  // msg->set_paccuint64_26(1);
  // msg->set_paccuint64_27(1);
  // msg->set_paccuint64_28(1);
  // msg->set_paccuint64_29(1);
  // msg->set_paccuint64_30(1);
  // msg->set_paccuint64_31(1);
  // msg->set_paccuint64_32(1);
  // msg->set_paccuint64_33(1);
  // msg->set_paccuint64_34(1);
  // msg->set_paccuint64_35(1);
  // msg->set_paccuint64_36(1);
  // msg->set_paccuint64_37(1);
  // msg->set_paccuint64_38(1);
  // msg->set_paccuint64_39(1);
  // msg->set_paccuint64_40(1);
  // msg->set_paccuint64_41(1);
  // msg->set_paccuint64_42(1);
  // msg->set_paccuint64_43(1);
  // msg->set_paccuint64_44(1);
  // msg->set_paccuint64_45(1);
  // msg->set_paccuint64_46(1);
  // msg->set_paccuint64_47(1);
  // msg->set_paccuint64_48(1);
  // msg->set_paccuint64_49(1);
  // msg->set_paccuint64_50(1);
  // msg->set_paccuint64_51(1);
  // msg->set_paccuint64_52(1);
  // msg->set_paccuint64_53(1);
  // msg->set_paccuint64_54(1);
  // msg->set_paccuint64_55(1);
  // msg->set_paccuint64_56(1);
  // msg->set_paccuint64_57(1);
  // msg->set_paccuint64_58(1);
  // msg->set_paccuint64_59(1);
  // msg->set_paccuint64_60(1);
  // msg->set_paccuint64_61(1);
  // msg->set_paccuint64_62(1);
  // msg->set_paccuint64_63(1);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_PaccboolMessageMessage);
  // protolib::Paccser_boolMessage* nested = google::protobuf::Arena::CreateMessage<protolib::Paccser_boolMessage>(&arena);
  // nested->set_paccbool_0(false);
  // msg->set_allocated_paccpaccser_boolmessage_0(nested);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_PaccdoubleMessageMessage);
  // protolib::Paccser_doubleMessage* nested = google::protobuf::Arena::CreateMessage<protolib::Paccser_doubleMessage>(&arena);
  // nested->set_paccdouble_0(false);
  // msg->set_allocated_paccpaccser_doublemessage_0(nested);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }
  //
  // {
  // CREATE_MSG_PTR(protolib, Paccser_PaccstringMessageMessage);
  // protolib::Paccser_stringMessage* nested = google::protobuf::Arena::CreateMessage<protolib::Paccser_stringMessage>(&arena);
  // nested->set_paccstring_0("0123");
  // msg->set_allocated_paccpaccser_stringmessage_0(nested);
  // print_desc(desc, reinterpret_cast<char*>(msg));
  // }

  // TODO: Do one of the new protos and compare


  return 0;
}
