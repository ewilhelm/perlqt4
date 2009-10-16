#include "QtCore/QObject"

#include "marshall_types.h"
#include "binding.h"
#include "Qt.h"
#include "smokeperl.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

extern Q_DECL_EXPORT Smoke *qt_Smoke;
extern Q_DECL_EXPORT int do_debug;

namespace PerlQt {

Binding::Binding() : SmokeBinding(0) {};
Binding::Binding(Smoke *s) : SmokeBinding(s) {};

void Binding::deleted(Smoke::Index /*classId*/, void *ptr) {
    SV* obj = getPointerObject(ptr);
    smokeperl_object* o = sv_obj_info(obj);
    if (!o || !o->ptr) {
        return;
    }
    unmapPointer( o, o->classId, 0 );

    // If it's a QObject, unmap all it's children too.
    if ( isDerivedFrom( o->smoke, o->classId, o->smoke->idClass("QObject").index, 0 ) >= 0 ) {
        QObject* objptr = (QObject*)o->smoke->cast(
            ptr,
            o->classId,
            o->smoke->idClass("QObject").index
        );
        QObjectList mychildren = objptr->children();
        foreach( QObject* child, mychildren ) {
            deleted( 0, child );
        }
    }

    o->ptr = 0;
}

bool Binding::callMethod(Smoke::Index method, void *ptr, Smoke::Stack args, bool isAbstract) {
    PERL_SET_CONTEXT(PL_curinterp); // for threads

    dbg_p(qtdb_virtual|qtdb_verbose,
      "Looking for virtual method override for %p->%s::%s()\n",
      ptr,
      qt_Smoke->classes[qt_Smoke->methods[method].classId].className,
      qt_Smoke->methodNames[qt_Smoke->methods[method].name]
    );

    // Look for a perl sv associated with this pointer
    SV *obj = getPointerObject(ptr);
    smokeperl_object *o = sv_obj_info(obj);

    // Didn't find one
    if(!o) {
#ifdef DEBUG
        if(!PL_dirty)// If not in global destruction
            dbg_p(qtdb_virtual|qtdb_verbose,
              "Cannot find object for virtual method\n");
#endif
        return false;
    }

    // see if anybody defined this method in perl
    const char *methodname = smoke->methodNames[smoke->methods[method].name];
    HV *stash = SvSTASH(SvRV(obj));
    GV *gv = gv_fetchmethod_autoload(stash, methodname, 0);
    if(! (gv && GvCV(gv))) return false;

    // XXX this is a bit heavy vs just not populating virtual methods!
    // but see if this was just c++ code defined in populate_class()
    HV* notes = get_hv(form("%s::%s", 
      CvSTASH(GvCV(gv)) ?
        HvNAME(CvSTASH(GvCV(gv))) : HvNAME(GvSTASH(gv)), "_CXXCODE"), 0
      );
    if(notes and hv_exists(notes, methodname, strlen(methodname)))
        return false;

#ifdef DEBUG
    if( do_debug && ( do_debug & qtdb_virtual ) )
        fprintf(stderr, "In Virtual override for %s\n", methodname);
#endif

    VirtualMethodCall call(smoke, method, args, obj, gv);
    call.next();
    return true;
}

// Args: Smoke::Index classId: the smoke classId to get the perl package name for
// Returns: char* containing the perl package name
char* Binding::className(Smoke::Index classId) {
    // XXX I suspect that this is not needed.
    // Find the classId->package hash
    HV* classId2package = get_hv( "Qt::_internal::classId2package", FALSE );
    if( !classId2package ) croak( "Internal error: Unable to find classId2package hash" );

    // Look up the package's name in the hash
    char* key = new char[4];
    int klen = sprintf( key, "%d", classId );
    //*(key + klen) = 0;
    SV** packagename = hv_fetch( classId2package, key, klen, FALSE );
    delete[] key;

    if( !packagename ) {
        // Shouldn't happen
        croak( "Internal error: Unable to resolve classId %d to perl package",
               classId );
    }

    return SvPV_nolen(*packagename);
}

} // End namespace PerlQt
