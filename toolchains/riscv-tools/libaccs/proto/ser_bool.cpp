
#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>
#include <cinttypes>
#include <chrono>

#include "primitives.pb.h"

#ifdef __riscv
#include "../accellib.h"
#endif

using namespace std;


int main() {

    GOOGLE_PROTOBUF_VERIFY_VERSION;



        std::cout << "s1\n" << std::flush;

        #ifdef __riscv
        string hostplat = "riscv";

        volatile char ** serializeoutputs = AccelSetupSerializer();

        #else
        string hostplat = "x86";
        #endif


        std::cout << "s2\n" << std::flush;

        #define NUMTESTVALS 5
bool testvals[NUMTESTVALS] = {  true, true, true, true, true };



        std::cout << "s3\n" << std::flush;

            std::cout << "s4\n" << std::flush;

            google::protobuf::Arena arena;

            primitivetests::Paccser_boolMessage* fillmessage = google::protobuf::Arena::CreateMessage<primitivetests::Paccser_boolMessage>(&arena);

               fillmessage->set_paccbool_0(testvals[0]);
               fillmessage->set_paccbool_1(testvals[1]);
               fillmessage->set_paccbool_2(testvals[2]);
               fillmessage->set_paccbool_3(testvals[3]);
               fillmessage->set_paccbool_4(testvals[4]);


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

            string outstr;
            fillmessage->SerializeToString(&outstr);
            char * cpuserialized = (char*)outstr.c_str();
            int cpuserialized_len = outstr.length();

            std::cout << "CPU: SERIALIZEDLENGTH: " << cpuserialized_len << "\n" << std::flush;
            for (int l = 0; l < cpuserialized_len; l++) {
                printf("cpubyte: %02x\n", cpuserialized[l]);
            }

            uint64_t singleserializedlen = outstr.length();
            std::cout << "encodedlen " << singleserializedlen << "\n" << std::flush;
            uint64_t total_bytes_processed = singleserializedlen * SERITERS;


#ifdef __riscv
            std::cout << "s5\n" << std::flush;

            auto t1 = std::chrono::steady_clock::now();
            for (int iterser = 0; iterser < SERITERS; iterser++) {
                AccelSerializeToString(primitivetests, Paccser_boolMessage, parseintos[iterser]);
            }

            volatile char * serres = BlockOnSerializedValue(serializeoutputs, SERITERS-1);
            size_t serlen = GetSerializedLength(serializeoutputs, SERITERS-1);

            auto t2 = std::chrono::steady_clock::now();
            auto duration1 = std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();
            std::cout << (duration1 / (SERITERS * 1.0)) << ", us per iter, " << hostplat << "-accel, ser_bool, " << testvals[0] << "\n" << std::flush;
            std::cout << (((double)(total_bytes_processed)) / (((double)duration1) / 1000000.0)  / 1000000000.0 * 8) << ", Gbits/s, " << hostplat << "-accel, ser_bool, " << testvals[0] << "\n" << std::flush;

            std::cout << "ACCEL: SERIALIZEDLENGTH: " << serlen << ", SERPTR: " << ((uint64_t)serres) << "\n" << std::flush;
            for (int l = 0; l < serlen; l++) {
                printf("accelbyte: %02x\n", serres[l]);
            }


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

#endif

            std::cout << "s6\n" << std::flush;

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

        std::cout << "s7\n" << std::flush;

        google::protobuf::ShutdownProtobufLibrary();
        return 0;
}
