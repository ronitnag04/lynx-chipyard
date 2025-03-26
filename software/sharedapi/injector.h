#ifndef INJECTOR_H
#define INJECTOR_H

#include <exception>

class StolenException: public std::exception {};
void CheckIfStolen(void);
void RequestStop(void);

#endif
