#ifndef QT_H
#define QT_H

#include "smokeperl.h"
#include "smokehelp.h"

SV* allocSmokePerlSV ( void* ptr, SmokeType type );
#ifdef DEBUG
SV* catArguments(SV** sp, int n);
SV* catCallerInfo( int count );
#endif
const char* get_SVt(SV* sv);
SV* getPointerObject(void* ptr);
int isDerivedFrom(Smoke *smoke, Smoke::Index classId, Smoke::Index baseId, int cnt);
void mapPointer(SV *obj, smokeperl_object *o, HV *hv, Smoke::Index classId, void *lastptr);
Smoke::Index package_classId(const char *package);
void unmapPointer( smokeperl_object* o, Smoke::Index classId, void* lastptr);

extern HV* pointer_map;
extern int do_debug;

#ifdef DEBUG
inline void dbg_p(int flag, char* format, ...) {
  va_list args;
  if(! (do_debug && ((do_debug & flag) == flag))) return;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
}
#else
#define dbg_p(flag, format, args...) ((void)0)
#endif

#endif // QT_H
