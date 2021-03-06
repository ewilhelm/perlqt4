#ifndef SMOKEPERL_H
#define SMOKEPERL_H

#include "smoke.h"
#include "smokehelp.h"

struct smokeperl_object {
    bool allocated;
    Smoke* smoke;
    int classId;
    void* ptr;
};

inline smokeperl_object* sv_obj_info(SV* sv) { // ptr on success, null on fail
    if(!sv || !SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVHV)
        return 0;
    SV *obj = SvRV(sv);
    MAGIC *mg = mg_find(obj, '~');
    if(!mg ){//|| mg->mg_virtual != &vtbl_smoke) {
        // FIXME: die or something?
        return 0;
    }
    smokeperl_object *o = (smokeperl_object*)mg->mg_ptr;
    return o;
}

// keep this enum in sync with lib/Qt/debug.pm
enum QtDebugChannel {
    qtdb_none = 0x00,
    qtdb_ambiguous = 0x01,
    qtdb_autoload = 0x02,
    qtdb_calls = 0x04,
    qtdb_gc = 0x08,
    qtdb_virtual = 0x10,
    qtdb_verbose = 0x20,
    qtdb_signals = 0x40,
    qtdb_slots = 0x80,
    qtdb_marshall = 0x100,
    qtdb_meta = 0x200,
};

enum MocArgumentType {
    xmoc_ptr,
    xmoc_bool,
    xmoc_int,
    xmoc_uint,
    xmoc_long,
    xmoc_ulong,
    xmoc_double,
    xmoc_charstar,
    xmoc_QString,
    xmoc_void
};

struct MocArgument {
    // smoke object and associated typeid
    SmokeType st;
    MocArgumentType argType;
};

#endif //SMOKEPERL_H
