#include "protolib.pb.h"

extern "C" {
#include "descriptor_printer.h"
}

using namespace protolib;

inline void fleetbench_rpc_P0_request_Message1_Set_4(fleetbench_rpc_P0_request_Message1* message, std::string* s) {
  fleetbench_rpc_P0_request_Message1::M1* v0 = message->mutable_f_15();
  fleetbench_rpc_P0_request_Message1::M1::M7* v1_0 = v0->mutable_f_5();
  v1_0->set_f_2(0x1079ba8b1aa46);
  fleetbench_rpc_P0_request_Message1::M1::M7* v1_1 = v0->mutable_f_5();
  v1_1->set_f_2(0x1e54);
  v1_1->set_f_0(false);
  v1_1->set_f_1(0x56);
  fleetbench_rpc_P0_request_Message1::M1::M13* v2 = v0->mutable_f_9();
  v2->set_f_0(s->substr(0, 71));
  fleetbench_rpc_P0_request_Message1::M1::M14* v3 = v0->mutable_f_10();
  v3->set_f_0(true);
  v3->set_f_1(0x2b27);
  message->set_f_0(s->substr(71, 79));
  message->set_f_1(s->substr(79, 327));
  message->set_f_4(0.632591);
  fleetbench_rpc_P0_request_Message1::M2* v4_0 = message->mutable_f_16();
  fleetbench_rpc_P0_request_Message1::M2::M12* v5 = v4_0->mutable_f_6();
  (void)v5;  // Suppresses clang-tidy.
  fleetbench_rpc_P0_request_Message1::M2::M11* v6 = v4_0->mutable_f_5();
  fleetbench_rpc_P0_request_Message1::M2::M11::M18* v7_0 = v6->mutable_f_4();
  v7_0->set_f_0(fleetbench_rpc_P0_request_Message1::M2::M11::M18::E2_CONST_1);
  v7_0->set_f_1(0x4d);
  fleetbench_rpc_P0_request_Message1::M2::M11::M18* v7_1 = v6->mutable_f_4();
  v7_1->set_f_0(fleetbench_rpc_P0_request_Message1::M2::M11::M18::E2_CONST_5);
  v6->set_f_0(s->substr(327, 10856));
  fleetbench_rpc_P0_request_Message1::M2* v4_1 = message->mutable_f_16();
  v4_1->set_f_0(false);
  fleetbench_rpc_P0_request_Message1::M2::M5* v8 = v4_1->mutable_f_3();
  v8->set_f_0(false);
  fleetbench_rpc_P0_request_Message1::M4* v9 = message->mutable_f_18();
  v9->set_f_1(0x31);
  fleetbench_rpc_P0_request_Message1::M4::M6* v10_0 = v9->mutable_f_8();
  fleetbench_rpc_P0_request_Message1::M4::M6::M19* v11 = v10_0->mutable_f_2();
  v11->set_f_2(s->substr(10856, 10878));
  v11->set_f_0(s->substr(10878, 11132));
  v11->set_f_1(0x15bbaabbd63);
  v11->set_f_3(0xc52e63cc85cbb0e);
  fleetbench_rpc_P0_request_Message1::M4::M6* v10_1 = v9->mutable_f_8();
  fleetbench_rpc_P0_request_Message1::M4::M6::M19* v12 = v10_1->mutable_f_2();
  v12->set_f_0(s->substr(11132, 11151));
  v12->set_f_1(0x623ccd210);
  v12->set_f_3(0x200fe8d6dbb5b9ba);
  v10_1->set_f_0(0x20);
  fleetbench_rpc_P0_request_Message1::M4::M10* v13 = v9->mutable_f_10();
  v13->set_f_0(0x6beae6a);
  fleetbench_rpc_P0_request_Message1::M4::M15* v14 = v9->mutable_f_11();
  v14->set_f_0(0.622860);
  message->set_f_6(s->substr(11151, 11254));
  message->set_f_2(s->substr(11254, 11257));
  fleetbench_rpc_P0_request_Message1::M3* v15_0 = message->mutable_f_17();
  fleetbench_rpc_P0_request_Message1::M3::M16* v16 = v15_0->mutable_f_10();
  v16->set_f_10(0x3d22c58de4580fdb);
  v16->set_f_12(false);
  v16->set_f_13(fleetbench_rpc_P0_request_Message1::M3::M16::E1_CONST_4);
  v16->set_f_1(s->substr(11257, 11282));
  v16->set_f_0(true);
  v16->set_f_5(true);
  v16->set_f_4(s->substr(11282, 11284));
  v16->set_f_3(0x33fd96a12);
  v16->set_f_11(s->substr(11284, 11289));
  v16->set_f_14(s->substr(11289, 11321));
  fleetbench_rpc_P0_request_Message1::M3::M9* v17 = v15_0->mutable_f_6();
  v17->set_f_0(true);
  v15_0->set_f_0(0x2ede);
  v15_0->set_f_1(0xb);
  fleetbench_rpc_P0_request_Message1::M3* v15_1 = message->mutable_f_17();
  v15_1->set_f_1(0x37);
  v15_1->set_f_0(0x489);
  fleetbench_rpc_P0_request_Message1::M3::M16* v18 = v15_1->mutable_f_10();
  v18->set_f_4(s->substr(11321, 11332));
  v18->set_f_13(fleetbench_rpc_P0_request_Message1::M3::M16::E1_CONST_5);
  v18->set_f_0(true);
  v18->set_f_9(true);
  v18->set_f_1(s->substr(11332, 11350));
  v18->set_f_10(0x3d5567eb971e7763);
  v18->set_f_7(s->substr(11350, 11359));
  v18->set_f_12(true);
  v18->set_f_14(s->substr(11359, 11791));
  v18->set_f_11(s->substr(11791, 11794));
}

#define ACCEL_DESC(filename, msgtype) filename##_FriendStruct_##msgtype##_ACCEL_DESCRIPTORS::msgtype##_ACCEL_DESCRIPTORS
#define CREATE_MSG_PTR(filename, msgtype) \
  filename::msgtype* msg = google::protobuf::Arena::CreateMessage<filename::msgtype>(&arena); \
  const uint64_t* desc = ACCEL_DESC(filename, msgtype)

int main(int argc, char** argv) {
  GOOGLE_PROTOBUF_VERIFY_VERSION;
  google::protobuf::Arena arena;

  std::string s(12000, 'a');
  CREATE_MSG_PTR(protolib, RequestMessage);
  protolib::P0RequestMessage* msginner = msg->mutable_p0();
  fleetbench_rpc_P0_request_Message1_Set_4(msginner->mutable_m_1(), &s);
  print_desc(desc, reinterpret_cast<char*>(msg));

  return 0;
}
