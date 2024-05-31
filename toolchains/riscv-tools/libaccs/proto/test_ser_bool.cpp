
#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>
#include <cinttypes>
#include <chrono>

#include "primitives_ser.pb.h"

#include "accellib.h"

using namespace std;


int main() {
	GOOGLE_PROTOBUF_VERIFY_VERSION;
// Initialize output region (accelerator)
	volatile char ** serializeoutputs = AccelSetupSerializer();

// Test values
#define NUMTESTVALS 5
	bool testvals[NUMTESTVALS] = {  true, true, true, true, true };

// Fill one message with the test values
	google::protobuf::Arena arena;
	primitivetests::Paccser_boolMessage* fillmessage = google::protobuf::Arena::CreateMessage<primitivetests::Paccser_boolMessage>(&arena);
	fillmessage->set_paccbool_0(testvals[0]);
	fillmessage->set_paccbool_1(testvals[1]);
	fillmessage->set_paccbool_2(testvals[2]);
	fillmessage->set_paccbool_3(testvals[3]);
	fillmessage->set_paccbool_4(testvals[4]);

// Fill each message of parseintos[1000] with the test values
#define SERITERS 1000
	primitivetests::Paccser_boolMessage* parseintos[SERITERS];
	for (int q = 0; q < SERITERS; q++) {
		parseintos[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccser_boolMessage>(&arena);
		fillmessage = parseintos[q];
		fillmessage->set_paccbool_0(testvals[0]);
		fillmessage->set_paccbool_1(testvals[1]);
		fillmessage->set_paccbool_2(testvals[2]);
		fillmessage->set_paccbool_3(testvals[3]);
		fillmessage->set_paccbool_4(testvals[4]);
	}

// CPU serialization: SerializeToString
	string outstr;
	fillmessage->SerializeToString(&outstr);
	char * cpuserialized = (char*)outstr.c_str();
	int cpuserialized_len = outstr.length();
	std::cout << "CPU: SERIALIZEDLENGTH: " << cpuserialized_len << "\n" << std::flush;
	for (int l = 0; l < cpuserialized_len; l++) {
		printf("cpubyte: %02x\n", cpuserialized[l]);
	}
// Just serialize one message and report total bytes by multiplying 1000
	uint64_t singleserializedlen = outstr.length();
	std::cout << "encodedlen " << singleserializedlen << "\n" << std::flush;
	uint64_t total_bytes_processed = singleserializedlen * SERITERS;

            
// Accelerator serialization
	auto t1 = std::chrono::steady_clock::now();	
// Serialize parseintos[i] (i=0~999)
	for (int iterser = 0; iterser < SERITERS; iterser++) {
		AccelSerializeToString(primitivetests, Paccser_boolMessage, parseintos[iterser]);
	}
// Get Serialized(parseintos[999])
	volatile char * serres = BlockOnSerializedValue(serializeoutputs, SERITERS-1);
	size_t serlen = GetSerializedLength(serializeoutputs, SERITERS-1);
// Measure time
	auto t2 = std::chrono::steady_clock::now();
	auto duration1 = std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();
	std::cout << (duration1 / (SERITERS * 1.0)) << ", us per iter, " << hostplat << "-accel, ser_bool, " << testvals[0] << "\n" << std::flush;
	std::cout << (((double)(total_bytes_processed)) / (((double)duration1) / 1000000.0)  / 1000000000.0 * 8) << ", Gbits/s, " << hostplat << "-accel, ser_bool, " << testvals[0] << "\n" << std::flush;
// Check length and bytes of Serialized(parseintos[999])
	std::cout << "ACCEL: SERIALIZEDLENGTH: " << serlen << ", SERPTR: " << ((uint64_t)serres) << "\n" << std::flush;
	for (int l = 0; l < serlen; l++) {
		printf("accelbyte: %02x\n", serres[l]);
	}
// Verify output length and bytes
	for (int iterser = 0; iterser < SERITERS; iterser++) {
		volatile char * serres = BlockOnSerializedValue(serializeoutputs, iterser);
		size_t serlen = GetSerializedLength(serializeoutputs, iterser);

		if (serlen != cpuserialized_len) {
			printf("FAIL MISMATCHED LEN\n");
			exit(1);
		}
		for (int l = 0; l < serlen; l++) {
			if (cpuserialized[l] != serres[l]) {
				printf("FAIL MISMATCHED VALUE\n");
			}
		}
	}

// CPU serialization: SerializeToArray() 
	primitivetests::Paccser_boolMessage* parseintoscpu[SERITERS];

	char * seroutputscpu[SERITERS];
	for (int out = 0; out < SERITERS; out++) {
		seroutputscpu[out] = (char*)malloc(singleserializedlen*2);
	}

	for (int q = 0; q < SERITERS; q++) {
		parseintoscpu[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccser_boolMessage>(&arena);
		fillmessage = parseintoscpu[q];
		fillmessage->set_paccbool_0(testvals[0]);
		fillmessage->set_paccbool_1(testvals[1]);
		fillmessage->set_paccbool_2(testvals[2]);
		fillmessage->set_paccbool_3(testvals[3]);
		fillmessage->set_paccbool_4(testvals[4]);
	}
  auto t3 = std::chrono::steady_clock::now();
	for (int i = 0; i < SERITERS; i++) {
		parseintoscpu[i]->SerializeToArray(seroutputscpu[i], singleserializedlen*2);
	}
  auto t4 = std::chrono::steady_clock::now();
	auto duration2 = std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3).count();
	std::cout << (duration2 / (SERITERS * 1.0)) << ", us per iter, " << hostplat << ", ser_bool, " << testvals[0] << "\n" << std::flush;
	std::cout << (((double)(total_bytes_processed)) / (((double)duration2) / 1000000.0)  / 1000000000.0 * 8) << ", Gbits/s, " << hostplat << ", ser_bool, " << testvals[0] << "\n" << std::flush;

	char * serrescpu = seroutputscpu[SERITERS-1];
  size_t serlencpu = singleserializedlen;
	if (serlencpu != cpuserialized_len) {
		printf("FAIL MISMATCHED LEN\n");
		exit(1);
	}
	for (int l = 0; l < serlencpu; l++) {
		if (cpuserialized[l] != serrescpu[l]) {
			printf("FAIL MISMATCHED VALUE\n");
		}
	}
  
// End of testing
	google::protobuf::ShutdownProtobufLibrary();
  
	return 0;
}
