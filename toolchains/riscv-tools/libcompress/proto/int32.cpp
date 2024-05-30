
#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>
#include <cinttypes>
#include <chrono>

#include "primitives_des.pb.h"

#ifdef __riscv
#include "accellib.h"
#endif

using namespace std;


int main() {

    GOOGLE_PROTOBUF_VERIFY_VERSION;



        std::cout << "s1\n" << std::flush;

        #ifdef __riscv
        string hostplat = "riscv";

        AccelSetup();

        #else
        string hostplat = "x86";
        #endif


        std::cout << "s2\n" << std::flush;

        #define NUMTESTVALS 1
int32_t testvals[NUMTESTVALS] = {  1 };



        std::cout << "s3\n" << std::flush;

            std::cout << "s4\n" << std::flush;

            google::protobuf::Arena arena;
            primitivetests::Paccint32Message* fillmessage = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);

            fillmessage->set_paccint32_0(testvals[0]);


            string outstr;
            fillmessage->SerializeToString(&outstr);

            #define ITERS 1000
            bool failcheck = false;

            std::cout << "encodedlen " << outstr.length() << "\n" << std::flush;
            uint64_t total_bytes_processed = outstr.length() * ITERS;

            primitivetests::Paccint32Message* parseintos[ITERS];

            for (int q = 0; q < ITERS; q++) {
               parseintos[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
            }

            string newstr[ITERS];
            for (int q = 0; q < ITERS; q++) {
                newstr[q] = outstr;
            }

    #ifdef __riscv
            std::cout << "s5\n" << std::flush;

            auto t1 = std::chrono::steady_clock::now();

            asm volatile ("fence");

            for (int q = 0; q < ITERS; q++) {
                AccelParseFromString(primitivetests, Paccint32Message, parseintos[q], newstr[q]);
            }

            block_on_completion();

            if ( (parseintos[ITERS-1]->paccint32_0() != fillmessage->paccint32_0())  ) {
                failcheck = true;
            }

            auto t2 = std::chrono::steady_clock::now();
            auto duration1 = std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();
            std::cout << (duration1 / (ITERS * 1.0)) << ", us per iter, " << hostplat << "-accel, int32, " << testvals[0] << "\n" << std::flush;

            std::cout << (((double)(total_bytes_processed)) / (((double)duration1) / 1000000.0)  / 1000000000.0 * 8) << ", Gbits/s, " << hostplat << "-accel, int32, " << testvals[0] << "\n" << std::flush;

            if (failcheck) {
                std::cout << "FAIL WRITE NOT IMMEDIATELY VISIBILE OR INCORRECT.\n" << std::flush;
            }

            for (int q = 0; q < ITERS; q++) {
                if (parseintos[q]->paccint32_0() != fillmessage->paccint32_0()) {
                    std::cout << "ACCEL FAILED ITER " << q << " ON int32 TEST!\n" << std::flush;
                    exit(1);
                }
                if (!(parseintos[q]->has_paccint32_0())) {
                    std::cout << "ACCEL FAILED hasbits ITER " << q << " ON int32 TEST!\n" << std::flush;
                    exit(1);
                }
            }
    #endif
            std::cout << "s6\n" << std::flush;

            primitivetests::Paccint32Message* parseintoscpu[ITERS];

            for (int q = 0; q < ITERS; q++) {
               parseintoscpu[q] = google::protobuf::Arena::CreateMessage<primitivetests::Paccint32Message>(&arena);
            }

            auto t3 = std::chrono::steady_clock::now();
            for (int i = 0; i < ITERS; i++) {
                parseintoscpu[i]->ParseFromString(newstr[i]);
            }

            auto t4 = std::chrono::steady_clock::now();
            auto duration2 = std::chrono::duration_cast<std::chrono::microseconds>(t4 - t3).count();

            std::cout << (duration2 / (ITERS * 1.0)) << ", us per iter, " << hostplat << ", int32, " << testvals[0] << "\n" << std::flush;

            std::cout << (((double)(total_bytes_processed)) / (((double)duration2) / 1000000.0)  / 1000000000.0 * 8) << ", Gbits/s, " << hostplat << ", int32, " << testvals[0] << "\n" << std::flush;

            if (fillmessage->paccint32_0() != parseintoscpu[ITERS-1]->paccint32_0()) {
                printf("FAILED int32 test.\n");
                exit(1);
            } else if (!(parseintoscpu[ITERS-1]->has_paccint32_0())) {
                printf("FAILED hasbits for int32 test.\n");
                exit(1);
            } else {
                printf("PASSED int32 test.\n");
            }


        std::cout << "s7\n" << std::flush;

        google::protobuf::ShutdownProtobufLibrary();
        return 0;
}
