#include "QtCore/QHash"
#include "QtCore/QMap"
#include "QtCore/QVector"
#include <QtDBus/QtDBus>

#include "smoke.h"
#include "marshall_types.h"
#include "smokeperl.h" // for smokeperl_object
#include "smokehelp.h" // for SmokeType and SmokeClass
#include "handlers.h" // for getMarshallType
#include "Qt.h" // for debug stuff

extern Smoke* qt_Smoke;

void
smokeStackToQtStack(Smoke::Stack stack, void ** o, int start, int end, QList<MocArgument*> args)
{
    for (int i = start, j = 0; i < end; ++i, ++j) {
        Smoke::StackItem *si = stack + j;
        switch(args[i]->argType) {
            case xmoc_bool:
                o[j] = &si->s_bool;
                break;
            case xmoc_int:
                o[j] = &si->s_int;
                break;
            case xmoc_uint:
                o[j] = &si->s_uint;
                break;
            case xmoc_long:
                o[j] = &si->s_long;
                break;
            case xmoc_ulong:
                o[j] = &si->s_ulong;
                break;
            case xmoc_double:
                o[j] = &si->s_double;
                break;
            case xmoc_charstar:
                o[j] = &si->s_voidp;
                break;
            case xmoc_QString:
                o[j] = si->s_voidp;
                break;
            default: {
                const SmokeType &t = args[i]->st;
                void *p;
                switch(t.elem()) {
                    case Smoke::t_bool:
                        p = &si->s_bool;
                        break;
                    case Smoke::t_char:
                        p = &si->s_char;
                        break;
                    case Smoke::t_uchar:
                        p = &si->s_uchar;
                        break;
                    case Smoke::t_short:
                        p = &si->s_short;
                        break;
                    case Smoke::t_ushort:
                        p = &si->s_ushort;
                        break;
                    case Smoke::t_int:
                        p = &si->s_int;
                        break;
                    case Smoke::t_uint:
                        p = &si->s_uint;
                        break;
                    case Smoke::t_long:
                        p = &si->s_long;
                        break;
                    case Smoke::t_ulong:
                        p = &si->s_ulong;
                        break;
                    case Smoke::t_float:
                        p = &si->s_float;
                        break;
                    case Smoke::t_double:
                        p = &si->s_double;
                        break;
                    case Smoke::t_enum: {
                        // allocate a new enum value
                        //Smoke::EnumFn fn = SmokeClass(t).enumFn();
                        Smoke::Class* _c = t.smoke()->classes + t.classId();
                        Smoke::EnumFn fn = _c->enumFn;
                        if (!fn) {
                            croak("Unknown enumeration %s\n", t.name());
                            p = new int((int)si->s_enum);
                            break;
                        }
                        Smoke::Index id = t.typeId();
                        (*fn)(Smoke::EnumNew, id, p, si->s_enum);
                        (*fn)(Smoke::EnumFromLong, id, p, si->s_enum);
                        // FIXME: MEMORY LEAK
                        break;
                    }
                    case Smoke::t_class:
                    case Smoke::t_voidp:
                        if (strchr(t.name(), '*') != 0) {
                            p = &si->s_voidp;
                        } else {
                            p = si->s_voidp;
                        }
                        break;
                    default:
                        p = 0;
                        break;
                }
                o[j] = p;
            }
        }
    }
}

void
smokeStackFromQtStack(Smoke::Stack stack, void ** _o, int start, int end, QList<MocArgument*> args)
{
    for (int i = start, j = 0; i < end; ++i, ++j) {
        void *o = _o[j];
        switch(args[i]->argType) {
            case xmoc_bool:
                stack[j].s_bool = *(bool*)o;
                break;
            case xmoc_int:
                stack[j].s_int = *(int*)o;
                break;
            case xmoc_uint:
                stack[j].s_uint = *(uint*)o;
                break;
            case xmoc_long:
                stack[j].s_long = *(long*)o;
                break;
            case xmoc_ulong:
                stack[j].s_ulong = *(ulong*)o;
                break;
            case xmoc_double:
                stack[j].s_double = *(double*)o;
                break;
            case xmoc_charstar:
                stack[j].s_voidp = o;
                break;
            case xmoc_QString:
                stack[j].s_voidp = o;
                break;
            default: { // case xmoc_ptr:
                const SmokeType &t = args[i]->st;
                void *p = o;
                switch(t.elem()) {
                    case Smoke::t_bool:
                        stack[j].s_bool = *(bool*)o;
                        break;
                    case Smoke::t_char:
                        stack[j].s_char = *(char*)o;
                        break;
                    case Smoke::t_uchar:
                        stack[j].s_uchar = *(unsigned char*)o;
                        break;
                    case Smoke::t_short:
                        stack[j].s_short = *(short*)p;
                        break;
                    case Smoke::t_ushort:
                        stack[j].s_ushort = *(unsigned short*)p;
                        break;
                    case Smoke::t_int:
                        stack[j].s_int = *(int*)p;
                        break;
                    case Smoke::t_uint:
                        stack[j].s_uint = *(unsigned int*)p;
                        break;
                    case Smoke::t_long:
                        stack[j].s_long = *(long*)p;
                        break;
                    case Smoke::t_ulong:
                        stack[j].s_ulong = *(unsigned long*)p;
                        break;
                    case Smoke::t_float:
                        stack[j].s_float = *(float*)p;
                        break;
                    case Smoke::t_double:
                        stack[j].s_double = *(double*)p;
                        break;
                    case Smoke::t_enum:
                        {
                            //Smoke::EnumFn fn = SmokeClass(t).enumFn();
                            Smoke::Class* _c = t.smoke()->classes + t.classId();
                            Smoke::EnumFn fn = _c->enumFn;
                            if (!fn) {
                                croak("Unknown enumeration %s\n", t.name());
                                stack[j].s_enum = **(int**)p;
                                break;
                            }
                            Smoke::Index id = t.typeId();
                            (*fn)(Smoke::EnumToLong, id, p, stack[j].s_enum);
                        }
                        break;
                    case Smoke::t_class:
                    case Smoke::t_voidp:
                        if (strchr(t.name(), '*') != 0) {
                            stack[j].s_voidp = *(void **)p;
                        } else {
                            stack[j].s_voidp = p;
                        }
                        break;
                }
            }
        }
    }
}

namespace PerlQt {

    MethodReturnValueBase::MethodReturnValueBase(Smoke *smoke, Smoke::Index methodIndex, Smoke::Stack stack) :
      _smoke(smoke), _methodIndex(methodIndex), _stack(stack) {
    }

    const Smoke::Method &MethodReturnValueBase::method() {
        return _smoke->methods[_methodIndex];
    }

    Smoke::StackItem &MethodReturnValueBase::item() {
        return _stack[0];
    }

    Smoke *MethodReturnValueBase::smoke() {
        return _smoke;
    }

    SmokeType MethodReturnValueBase::type() {
        return SmokeType(_smoke, method().ret);
    }

    void MethodReturnValueBase::next() {
    }

    bool MethodReturnValueBase::cleanup() {
        return false;
    }

    void MethodReturnValueBase::unsupported() {
        croak("Cannot handle '%s' as return-type of %s::%s",
            type().name(),
            _smoke->className(method().classId),
            _smoke->methodNames[method().name]);
    }

    SV* MethodReturnValueBase::var() {
        return _retval;
    }

    //------------------------------------------------

    VirtualMethodReturnValue::VirtualMethodReturnValue(Smoke *smoke, Smoke::Index methodIndex, Smoke::Stack stack, SV *retval) :
      MethodReturnValueBase(smoke, methodIndex, stack) {
        _retval = retval;
        Marshall::HandlerFn fn = getMarshallFn(type());
        (*fn)(this);
    }
    
    Marshall::Action VirtualMethodReturnValue::action() {
        return Marshall::FromSV;
    }

    //------------------------------------------------

    MethodReturnValue::MethodReturnValue(Smoke *smoke, Smoke::Index methodIndex, Smoke::Stack stack) :
      MethodReturnValueBase(smoke, methodIndex, stack)  {
        _retval = newSV(0);
        Marshall::HandlerFn fn = getMarshallFn(type());
        (*fn)(this);
    }

    // We're passing an SV back to perl
    Marshall::Action MethodReturnValue::action() {
        return Marshall::ToSV;
    }

    //------------------------------------------------

    SlotReturnValue::SlotReturnValue(void ** o, SV * result, QList<MocArgument*> replyType) :
      _replyType(replyType), _result(result) {
		_stack = new Smoke::StackItem[1];
		Marshall::HandlerFn fn = getMarshallFn(type());
		(*fn)(this);
		
		QByteArray t(type().name());
		t.replace("const ", "");
		t.replace("&", "");
		if (t == "QDBusVariant") {
			*reinterpret_cast<QDBusVariant*>(o[0]) = *(QDBusVariant*) _stack[0].s_class;
		} else {
            // Save any address in zeroth element of the arrary of 'void*'s
            // passed to qt_metacall()
			void * ptr = o[0];
			smokeStackToQtStack(_stack, o, 0, 1, _replyType);
            // Only if the zeroth element of the array of 'void*'s passed to
            // qt_metacall() contains an address, is the return value of the
            // slot needed.
			if (ptr != 0) {
				*(void**)ptr = *(void**)(o[0]);
			}
		}
    }

    Smoke::StackItem &SlotReturnValue::item() {
        return _stack[0];
    }

    Smoke *SlotReturnValue::smoke() {
        return type().smoke();
    }

    SmokeType SlotReturnValue::type() {
        return _replyType[0]->st;
    }

    Marshall::Action SlotReturnValue::action() {
         return Marshall::FromSV;
    }

    void SlotReturnValue::next() {}

    bool SlotReturnValue::cleanup() {
        return false;
    }

    void SlotReturnValue::unsupported() {
        croak("Cannot handle '%s' as return-type of slot", //%s::%s for slot return value",
            type().name()
            //smoke()->className(method().classId),
            //smoke()->methodNames[method().name]);
        );
    }

    SV* SlotReturnValue::var() {
        return _result;
    }

    SlotReturnValue::~SlotReturnValue() {
        delete[] _stack;
    }

    //------------------------------------------------

    MethodCallBase::MethodCallBase(Smoke *smoke, Smoke::Index meth) :
        _smoke(smoke), _method(meth), _cur(-1), _called(false), _sp(0)  
    {  
        dbg_p(qtdb_marshall, "construct methodcallbase for %s\n",
          _smoke->methodNames[method().name]); 
    }

    MethodCallBase::MethodCallBase(Smoke *smoke, Smoke::Index meth, Smoke::Stack stack) :
        _smoke(smoke), _method(meth), _stack(stack), _cur(-1), _called(false), _sp(0) 
    {  
    }

    Smoke *MethodCallBase::smoke() { 
        return _smoke; 
    }

    SmokeType MethodCallBase::type() { 
        return SmokeType(_smoke, _args[_cur]); 
    }

    Smoke::StackItem &MethodCallBase::item() { 
        return _stack[_cur + 1]; 
    }

    const Smoke::Method &MethodCallBase::method() { 
        return _smoke->methods[_method]; 
    }

    void MethodCallBase::next() {
        int oldcur = _cur;
        _cur++;
        while( !_called && _cur < items() ) {
            dbg_p(qtdb_marshall, "getMarshallFn\n");
            Marshall::HandlerFn fn = getMarshallFn(type());
            dbg_p(qtdb_marshall, "got\n");

            // The handler will call this function recursively.  The control
            // flow looks like: 
            // MethodCallBase::next -> TypeHandler fn -> recurse back to next()
            // until all variables are marshalled -> callMethod -> TypeHandler
            // fn to clean up any variables they create
            dbg_p(qtdb_marshall, "call\n");
            (*fn)(this);
            dbg_p(qtdb_marshall, "called\n");
            _cur++;
        }

        callMethod();
        _cur = oldcur;
    }

    void MethodCallBase::unsupported() {
        croak("Cannot handle '%s' as argument of virtual method %s::%s",
                type().name(),
                _smoke->className(method().classId),
                _smoke->methodNames[method().name]);
    }

    const char* MethodCallBase::classname() {
        return _smoke->className(method().classId);
    }

    //------------------------------------------------

    VirtualMethodCall::VirtualMethodCall(Smoke *smoke, Smoke::Index meth, Smoke::Stack stack, SV *obj, GV *gv) :
      MethodCallBase(smoke,meth,stack), _gv(gv){

        dSP;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(obj); // pass the object along
        EXTEND(SP, items());
        _sp = SP + 1;
        for(int i = 0; i < items(); i++)
            _sp[i] = sv_newmortal();
        _args = _smoke->argumentList + method().args;
    }

    VirtualMethodCall::~VirtualMethodCall() {
        // XXX this used to decrement sv_this refcount...
    }

    Marshall::Action VirtualMethodCall::action() {
        return Marshall::ToSV;
    }

    SV *VirtualMethodCall::var() {
        return _sp[_cur];
    }

    int VirtualMethodCall::items() {
        return method().numArgs;
    }

    void VirtualMethodCall::callMethod() {
        if (_called) return;
        _called = true;

        dSP;
        // This defines how many arguments we're sending to the perl sub
        SP = _sp + items() - 1;
        PUTBACK;
        // Call the perl sub
        call_sv((SV*)GvCV(_gv), G_SCALAR);
        // Get the stack the perl sub returned
        SPAGAIN;
        // Marshall the return value back to c++, using the top of the stack
        VirtualMethodReturnValue r(_smoke, _method, _stack, POPs);
        PUTBACK;
        FREETMPS;
        LEAVE;
    }

    bool VirtualMethodCall::cleanup() {
        return false;
    }

    //------------------------------------------------

    MethodCall::MethodCall(Smoke *smoke, Smoke::Index method, smokeperl_object *call_this, SV **sp, int items):
      MethodCallBase(smoke,method), _this(call_this), _sp(sp), _items(items) {
        _stack = new Smoke::StackItem[items + 1];
        _args = _smoke->argumentList + _smoke->methods[_method].args;
        _retval = newSV(0);
    }

    MethodCall::~MethodCall() {
        delete[] _stack;
    }

    Marshall::Action MethodCall::action() {
        return Marshall::FromSV;
    }

    SV *MethodCall::var() {
        if(_cur < 0)
            return _retval;
        return *(_sp + _cur);
    }

    int MethodCall::items() {
        return _items;
    }

    bool MethodCall::cleanup() {
        return true;
    }

    const char *MethodCall::classname() {
        return MethodCallBase::classname();
    }

    //------------------------------------------------

    // The steps are:
    // Copy Qt stack to Smoke Stack
    // use next() to marshall the smoke stack
    // callMethod()
    // The rest is modeled after the VirtualMethodCall
    InvokeSlot::InvokeSlot(SV* call_this, char* methodname, QList<MocArgument*> args, void** a) :
      _args(args), _cur(-1), _called(false), _this(call_this), _a(a) {

        // _args[0] represents what would be the return value, which isn't an
        // actual argument.  Subtract 1 to account for this.
        _items = _args.count() - 1;
        _stack = new Smoke::StackItem[_items];
        // Create this on the heap.  Just saying _methodname = methodname only
        // leaves enough space for 1 char.
        _methodname = new char[strlen(methodname)+1];
        strcpy(_methodname, methodname);
        _sp = new SV*[_items];
        for(int i = 0; i < _items; ++i)
            _sp[i] = sv_newmortal();
        copyArguments();
    }

    InvokeSlot::~InvokeSlot() {
        delete[] _stack;
        delete[] _methodname;
    }

    Smoke *InvokeSlot::smoke() {
        return type().smoke();
    }

    Marshall::Action InvokeSlot::action() {
        return Marshall::ToSV;
    }

    const MocArgument& InvokeSlot::arg() {
        return *(_args[_cur + 1]);
    }

    SmokeType InvokeSlot::type() {
        return arg().st;
    }

    Smoke::StackItem &InvokeSlot::item() {
        return _stack[_cur];
    }

    SV* InvokeSlot::var() {
        return _sp[_cur];
    }

    void InvokeSlot::callMethod() {
        if (_called) return;
        _called = true;

        //Call the perl sub
        //Copy the way the VirtualMethodCall does it
        HV *stash = SvSTASH(SvRV(_this));

        GV *gv = gv_fetchmethod_autoload(stash, _methodname, 0);
        if(!gv) {
            fprintf( stderr, "Found no method named %s to call in slot\n", _methodname );
            return;
        }

#ifdef DEBUG
        if(do_debug && (do_debug & qtdb_slots)) {
            fprintf( stderr, "In slot call %s::%s\n", HvNAME(stash), _methodname );
            if(do_debug & qtdb_verbose) {
                fprintf(stderr, "with arguments (%s)\n", SvPV_nolen(sv_2mortal(catArguments(_sp, _items))));
            }
        }
#endif
        
        dSP;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(_this);
        EXTEND(SP, _items);
        for(int i=0;i<_items;++i){
            PUSHs(_sp[i]);
        }
        PUTBACK;
        int count = call_sv((SV*)GvCV(gv), _args[0]->argType == xmoc_void ? G_VOID : G_SCALAR);
        if ( count > 0 && _args[0]->argType != xmoc_void ) {
            SlotReturnValue r(_a, POPs, _args);
        }
    }

    void InvokeSlot::next() {
        int oldcur = _cur;
        ++_cur;
        while( !_called && _cur < _items ) {
            Marshall::HandlerFn fn = getMarshallFn(type());
            (*fn)(this);
            ++_cur;
        }

        callMethod();
        _cur = oldcur;
    }

    void InvokeSlot::unsupported() {
        croak("Cannot handle '%s' as argument of slot call",
              type().name() );
    }

    bool InvokeSlot::cleanup() {
        return false;
    }

    void InvokeSlot::copyArguments() {
        smokeStackFromQtStack( _stack, _a + 1, 1, _items + 1, _args );
    }

    //------------------------------------------------

    EmitSignal::EmitSignal(QObject *obj, int id, int items, QList<MocArgument*> args, SV** sp, SV* retval) :
      _args(args), _cur(-1), _called(false), _items(items), _obj(obj), _id(id), _retval(retval) {
        _sp = sp;
        _stack = new Smoke::StackItem[_items];
    }

    Marshall::Action EmitSignal::action() {
        return Marshall::FromSV;
    }

    const MocArgument& EmitSignal::arg() {
        return *(_args[_cur + 1]);
    }

    SmokeType EmitSignal::type() {
        return arg().st;
    }

    Smoke::StackItem &EmitSignal::item() {
        return _stack[_cur];
    }

    SV* EmitSignal::var() {
        return _sp[_cur];
    }

    Smoke *EmitSignal::smoke() {
        return type().smoke();
    }

    void EmitSignal::callMethod() {
        if (_called) return;
        _called = true;

        // Create the stack to send to the slots
        // +1 to _items to accomidate the return value
        void** o = new void*[_items+1];

        // o+1 because o[0] is the return value. _items+1 because we have to
        // accomidate for the offset of o[0] already being used
        smokeStackToQtStack(_stack, o + 1, 1, _items + 1, _args);
        // The 0 index stores the return value
        void* ptr;
        o[0] = &ptr;
        prepareReturnValue(o);

        _obj->metaObject()->activate(_obj, _id, o);
    }

    void EmitSignal::unsupported() {
        croak("Cannot handle '%s' as argument of slot call",
              type().name() );
    }

    void EmitSignal::next() {
        int oldcur = _cur;
        ++_cur;

        while(_cur < _items) {
            Marshall::HandlerFn fn = getMarshallFn(type());
            (*fn)(this);
            ++_cur;
        }

        callMethod();
        _cur = oldcur;
    }

    bool EmitSignal::cleanup() {
        return false;
    }

    void EmitSignal::prepareReturnValue(void** o){
        if (_args[0]->argType == xmoc_ptr) {
            QByteArray type(_args[0]->st.name());
            type.replace("const ", "");
            if (!type.endsWith('*')) {  // a real pointer type, so a simple void* will do
                if (type.endsWith('&')) {
                    type.resize(type.size() - 1);
                }
                if (type.startsWith("QList")) {
                    o[0] = new QList<void*>;
                } else if (type.startsWith("QVector")) {
                    o[0] = new QVector<void*>;
                } else if (type.startsWith("QHash")) {
                    o[0] = new QHash<void*, void*>;
                } else if (type.startsWith("QMap")) {
                    o[0] = new QMap<void*, void*>;
                //} else if (type == "QDBusVariant") {
                    //o[0] = new QDBusVariant;
                } else {
                    Smoke::ModuleIndex ci = qt_Smoke->findClass(type);
                    if (ci.index != 0) {
                        Smoke::ModuleIndex mi = ci.smoke->findMethod(type, type);
                        if (mi.index) {
                            Smoke::Class& c = ci.smoke->classes[ci.index];
                            Smoke::Method& meth = mi.smoke->methods[mi.smoke->methodMaps[mi.index].method];
                            Smoke::StackItem _stack[1];
                            c.classFn(meth.method, 0, _stack);
                            o[0] = _stack[0].s_voidp;
                        }
                    }
                }
            }
        } else if (_args[0]->argType == xmoc_QString) {
            o[0] = new QString;
        }
    }
} // End namespace PerlQt
