//util.h brings in all the required Qt headers.  This has to happen before the
//perl stuff below
#include "util.h"

// Perl headers
extern "C" {
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
}

// Now my own headers
#include "smoke.h"
#include "Qt.h"
#include "binding.h"
#include "smokeperl.h"
#include "marshall_types.h" // Method call classes
#include "handlers.h" // for install_handlers function

extern PerlQt::Binding binding;
extern Q_DECL_EXPORT Smoke* qt_Smoke;
extern Q_DECL_EXPORT void init_qt_Smoke();

MODULE = Qt                PACKAGE = Qt::_internal

PROTOTYPES: DISABLE

SV*
get_methods_for(classname)
        char* classname
    CODE:
        HV *hv = newHV(); // $method_name => [@ids]
        Smoke::Method * m = qt_Smoke->methods;
        // XXX this should just get the classid, then do a bisect search
        // on methods to hit just the handful of methods for the class.
        for(int i = 0; i < qt_Smoke->numMethods; i++) {
          if(0 != qstrcmp(classname,
            qt_Smoke->classes[m[i].classId].className))
              continue;

          const char * method = qt_Smoke->methodNames[m[i].name];
          I32 methodl = strlen(method);

          AV *id_list;

          if(SV **get = hv_fetch(hv, method, methodl, 0)) {
            if(get && SvOK(*get)) {
              id_list = (AV*) SvRV(*get);
            }
            else {
              croak("XS failure");
            }
          }
          else {
            id_list = newAV();
	        hv_store(hv, method, methodl, newRV_noinc((SV*) id_list), 0);
          }
          av_push(id_list, newSViv(i));
        }
        RETVAL = newRV_noinc((SV*)hv);
    OUTPUT:
        RETVAL

#// Args: none
#// Returns: an array of all classes that qt_Smoke knows about
SV*
getClassList()
    CODE:
        AV* av = newAV();
        for (int i = 1; i <= qt_Smoke->numClasses; i++) {
            av_push(av, newSVpv(qt_Smoke->classes[i].className, 0));
        }
        RETVAL = newRV_noinc((SV*)av);
    OUTPUT:
        RETVAL

#// args: none
#// returns: an array of all enum names that qt_Smoke knows about
SV*
getEnumList()
    CODE:
        AV *av = newAV();
        for(int i = 1; i < qt_Smoke->numTypes; i++) {
            Smoke::Type curType = qt_Smoke->types[i];
            if( (curType.flags & Smoke::tf_elem) == Smoke::t_enum )
                av_push(av, newSVpv(curType.name, 0));
        }
        RETVAL = newRV_noinc((SV*)av);
    OUTPUT:
        RETVAL

#// Args: int classId: a smoke classId
#// Returns: An array of strings defining the inheritance list for that class.
void
getIsa( classId )
        int classId
    PPCODE:
        Smoke::Index *parents =
            qt_Smoke->inheritanceList +
            qt_Smoke->classes[classId].parents;
        while(*parents)
            XPUSHs(sv_2mortal(newSVpv(qt_Smoke->classes[*parents++].className, 0)));

=head2 get_arg_types

Returns the C argument types for the given $method_id.

  @types = get_arg_types($method_id);

=cut

void
get_arg_types(method_id)
    int method_id
  PPCODE:
    Smoke::Method &method = qt_Smoke->methods[method_id];
    Smoke::Index* args = qt_Smoke->argumentList + method.args;
    for(int i = 0; i < method.numArgs; i++)
      XPUSHs(sv_2mortal(newSVpv(qt_Smoke->types[args[i]].name, 0)));

#// Args: int classId: a smoke classId
#// Returns: The number of arguments that method has
int
getNumArgs( methodId )
        int methodId
    CODE:
        Smoke::Method &method = qt_Smoke->methods[methodId];
        RETVAL = method.numArgs;
    OUTPUT:
        RETVAL

const char*
getSVt( sv )
        SV* sv
    CODE:
        RETVAL = get_SVt(sv);
    OUTPUT:
        RETVAL

#// Args: char* name: the c++ name of a Qt class
#// Returns: the smoke classId for that Qt class
int
idClass( name )
        char* name
    CODE:
        RETVAL = qt_Smoke->idClass(name).index;
    OUTPUT:
        RETVAL

#// Args: char* name: the c++ name of a Qt class
#// Returns: the smoke classId for that Qt class
const char*
classFromId( classId )
        int classId
    CODE:
        RETVAL = qt_Smoke->classes[classId].className;
    OUTPUT:
        RETVAL

void
installqt_metacall(package)
        char *package
    CODE:
        if(!package) XSRETURN_EMPTY;
        char *qt_metacall = new char[strlen(package) + 14];
        strcpy(qt_metacall, package);
        strcat(qt_metacall, "::qt_metacall");
        newXS(qt_metacall, XS_qt_metacall, __FILE__);
        delete[] qt_metacall;

void
installsignal(signalname)
        char *signalname
    CODE:
        if(!signalname) XSRETURN_EMPTY;
        newXS(signalname, XS_signal, __FILE__);

SV*
call_smoke(methodid, object, ...)
        int methodid
        SV* object
    CODE:
        
        PERL_SET_CONTEXT(PL_curinterp);
        dbg_p(qtdb_calls, "call_smoke %d\n", methodid);
        int wasitems = items;
        items -= 2;

        dbg_p(qtdb_calls, "call_smoke for %d - %s\n",
          qt_Smoke->methods[methodid].name,
          qt_Smoke->methodNames[qt_Smoke->methods[methodid].name]
        );

        static smokeperl_object nothis = { 0, 0, 0, false };
        smokeperl_object* call_this = 0;

        // see if the first argument was an object or undef
        if ( SvOK(object) ) {
            if( ! (call_this = sv_obj_info( object )) )
                call_this = &nothis;
        }
        else {
            call_this = &nothis;
        }

        // MethodCall tries to write into the stack, so we have to copy it
        SV ** mystack = new SV*[items];
        for(int i = 0; i < items; i++)
          mystack[i] = ST(wasitems-items+i);

        if(!qt_Smoke->methods[methodid].flags & Smoke::mf_static) {
          if(!call_this->smoke) croak("not a static function");
        }

        dbg_p(qtdb_calls, "setup for %d\n",
          qt_Smoke->methods[methodid].name);

        PerlQt::MethodCall call(
          qt_Smoke, methodid, call_this, mystack, items);
        call.next();
        delete [] mystack;
        RETVAL = call.var();
        if(qt_Smoke->methods[methodid].flags & Smoke::mf_ctor)
          sv_bless(RETVAL,
            gv_stashpv(SvPV_nolen(object), TRUE) );
    OUTPUT:
        RETVAL

#// This is because QMetaObject doesn't really have a proper public
#// constructor, let alone one that would marshall nicely from Perl.
#// When we've subclassed a Qt class in Perl, this is used to create
#// the metaObject -- but is very entangled to the perl code in
#// makeMetaData() via the stringdata_sv stuff.
SV*
make_metaObject(parentClassId,parentMeta,stringdata_sv,data_sv)
        SV* parentClassId
        SV* parentMeta
        SV* stringdata_sv
        SV* data_sv
    CODE:
        // Get the meta object of the super class, to inherit the super's
        // sig/slots
        QMetaObject* superdata;
        if( SvROK(parentMeta) ){
            // The parent class is a custom Perl class whose metaObject
            // was constructed at runtime
            superdata = (QMetaObject*)sv_obj_info(parentMeta)->ptr;
        }
        else {
            // The parent class is a Smoke class, so call metaObject() on the
            // instance to get it via a smoke library call
            //const char* classname = qt_Smoke->classes[SvIV(parentClassId)].className;
            //Smoke::Index methodId = getMethod(qt_Smoke, classname, "metaObject");
            Smoke::ModuleIndex nameMId = qt_Smoke->idMethodName("metaObject");
            Smoke::ModuleIndex classMId = { qt_Smoke, SvIV(parentClassId) };
            Smoke::ModuleIndex meth = qt_Smoke->findMethod(classMId, nameMId);
            if (meth.index > 0) {
                Smoke::Method &m = qt_Smoke->methods[qt_Smoke->methodMaps[meth.index].method];
                Smoke::ClassFn fn = meth.smoke->classes[m.classId].classFn;
                Smoke::StackItem args[1];
                (*fn)(m.method, 0, args);
                superdata = (QMetaObject*) args[0].s_voidp;
            }
            else {
                // Should never happen...
                croak( "Cannot find %s::metaObject() method\n",
                       qt_Smoke->classes[SvIV(parentClassId)].className );
            }
        }

        // Create the qt_meta_data array.
        int count = av_len((AV*)SvRV(data_sv)) + 1;
        uint* qt_meta_data = new uint[count];
        for (int i = 0; i < count; i++) {
            SV** datarow = av_fetch((AV*)SvRV(data_sv), i, 0);
            qt_meta_data[i] = (uint)SvIV(*datarow);
        }

        // Create the qt_meta_stringdata array.
        // Can't use string functions here, because these strings contain
        // null (0) bits, which the string functions will interpret as the end
        // of the string
        STRLEN len = SvLEN(stringdata_sv);
        char* qt_meta_stringdata = new char[len];
        memcpy( (void*)(qt_meta_stringdata), (void*)SvPV_nolen(stringdata_sv), len );

        // Define our meta object
        const QMetaObject staticMetaObject = {
            { superdata, qt_meta_stringdata,
              qt_meta_data, 0 }
        };
        QMetaObject *meta = new QMetaObject;
        *meta = staticMetaObject;

        //Package up this pointer to be returned to perl
        smokeperl_object o;
        o.smoke = qt_Smoke;
        o.classId = qt_Smoke->idClass("QMetaObject").index,
        o.ptr = meta;
        o.allocated = true;

        HV *hv = newHV();
        RETVAL = newRV_noinc((SV*)hv);
        sv_bless( RETVAL, gv_stashpv( "Qt::MetaObject", TRUE ) );
        sv_magic((SV*)hv, 0, '~', (char*)&o, sizeof(o));
        //Not sure we need the entry in the pointer_map
        mapPointer(RETVAL, &o, pointer_map, o.classId, 0);
    OUTPUT:
        RETVAL

bool
isObject(obj)
        SV* obj
    CODE:
        RETVAL = sv_obj_info(obj) ? TRUE : FALSE;
    OUTPUT:
        RETVAL

void
setDebug(channel)
        int channel
    CODE:
        do_debug = channel;

int
getDebug()
    CODE:
        RETVAL = do_debug;
    OUTPUT:
        RETVAL

void*
sv_to_ptr(sv)
    SV* sv

MODULE = Qt                PACKAGE = Qt                

PROTOTYPES: ENABLE

BOOT:
    /* same as -DUSE_SAFE_PUTENV in compile. prevents a "free from wrong
     * pool during global destruction" error with debugperl; and a segfault
     * otherwise (due to invalid free)
     *
     * see also:
     * http://www.nntp.perl.org/group/perl.perl5.porters/2008/06/msg137726.html
     * http://www.qtsoftware.com/developer/task-tracker/index_html?id=217782&method=entry
     */
#ifndef PERL_USE_SAFE_PUTENV
    PL_use_safe_putenv = 1;
#endif

    init_qt_Smoke();
    binding = PerlQt::Binding(qt_Smoke);

    install_handlers(Qt_handlers);

    pointer_map = get_hv( "Qt::_internal::pointer_map", FALSE );

    newXS("Qt::qVariantFromValue", XS_qvariant_from_value, __FILE__);
    newXS("Qt::qVariantValue", XS_qvariant_value, __FILE__);
    newXS("Qt::Object::findChildren", XS_find_qobject_children, __FILE__);
    newXS("Qt::Object::qobject_cast", XS_qobject_qt_metacast, __FILE__);

    newXS("Qt::AbstractItemModel::createIndex", XS_qabstractitemmodel_createindex, __FILE__);
    // XXX should these be installed in a proper package or deleted?
    // newXS(" Qt::AbstractItemModel::rowCount", XS_qabstract_item_model_rowcount, __FILE__);
    // newXS(" Qt::AbstractItemModel::columnCount", XS_qabstract_item_model_columncount, __FILE__);
    // newXS(" Qt::AbstractItemModel::data", XS_qabstract_item_model_data, __FILE__);
    // newXS(" Qt::AbstractItemModel::setData", XS_qabstract_item_model_setdata, __FILE__);
    // newXS(" Qt::AbstractItemModel::rowCount", XS_qabstract_item_model_rowcount, __FILE__);
    // newXS(" Qt::AbstractItemModel::insertRows", XS_qabstract_item_model_insertrows, __FILE__);
    // newXS(" Qt::AbstractItemModel::insertColumns", XS_qabstract_item_model_insertcolumns, __FILE__);
    // newXS(" Qt::AbstractItemModel::removeRows", XS_qabstract_item_model_removerows, __FILE__);
    // newXS(" Qt::AbstractItemModel::removeColumns", XS_qabstract_item_model_removecolumns, __FILE__);
    // newXS(" Qt::ModelIndex::internalPointer", XS_qmodelindex_internalpointer, __FILE__);
