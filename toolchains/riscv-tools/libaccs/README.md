For proto, 
--------------------------------------------
Opcodes
0: decompressor
1: compressor
2: proto deserializer
3: proto serializer
4: memcpy
6: aes

Alternating opcodes
ex) Original opcode 0 --> Expanded opcode 0 and 1 (==instruction.funct[6])

Decompressor: Opcode=0, funct[6]=0
Compressor: Opcode=0, funct[6]=1
Proto Deserializer: Opcode=1, funct[6]=0
Proto Serializer: Opcode=1, funct[6]=1
Memcpy: Opcode=2, funct[6]=0
AES: Opcode=3, funct[6]=0
