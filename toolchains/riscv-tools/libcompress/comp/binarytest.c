#include <stdlib.h>
#include <stdio.h>
#include "benchmark_data_0.h"
#include <stdbool.h>

int main() {

// Test decompression
    FILE* file = fopen("arr.zst", "w");
    if(file!=NULL){
      fwrite(benchmark_compressed_data_0, sizeof(char), benchmark_compressed_data_0_len, file);
      fclose(file);
    }

    /*
    // Replace "your_binary_file" with the actual name of your binary file
    const char *binaryFileName = "./zstd -d arr.zst";
    // Construct the command to execute the binary file
    char command[100];  // Adjust the size as needed
    snprintf(command, sizeof(command), "%s", binaryFileName);
    // Use the system function to execute the command
    int result = system(command);
    // Check the result of the execution
    if (result == 0) {
      printf("Binary file executed successfully.\n");
    } else {
      printf("Error executing the binary file.\n");
    }
    */
    system("./zstd -d arr.zst");

    FILE* file2 = fopen("arr", "r");
    if(file2!=NULL){
      char* op =  (char*)malloc(benchmark_uncompressed_data_0_len + 1); 
      if(op!=NULL){
        fread(op, 1, benchmark_uncompressed_data_0_len, file2);
        
        // Compare result
        bool fail = false;
        for(int i=0; i<benchmark_uncompressed_data_0_len; ++i){
          char t = benchmark_uncompressed_data_0[i];
          if(t != op[i]){
            printf("char %d mismatch: expected %c but got %c\n", i, t, op[i]);
            fail = true;
          }
        }
        if(!fail) printf("Decompression success!\n");
        
        free(op);
      }
      fseek(file2, 0, SEEK_END);
      int size = ftell(file2);
      printf("Size of the decompressed file = %d bytes\n");
      fclose(file2);
    }
     
    return 0;
}
