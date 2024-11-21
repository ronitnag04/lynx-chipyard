#include "protolib.pb.h"

int main(int argc, char** argv) {
  GOOGLE_PROTOBUF_VERIFY_VERSION;
  google::protobuf::Arena arena;
  protolib::Int32ProtoDefinition* msg = google::protobuf::Arena::CreateMessage<protolib::Int32ProtoDefinition>(&arena);
  msg->set_f1(0x24);
  printf("YAY!\n");
  return 0;
}
