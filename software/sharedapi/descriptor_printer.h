#ifndef DESCRIPTOR_PRINTER_H
#define DESCRIPTOR_PRINTER_H

#define print_desc(DESC, MSG) print_desc_impl(DESC, MSG, 0);
void print_desc_impl(const uint64_t* desc, char* msg, size_t nest_amt);

#endif
