%module GASDK
%{
#include "../common.h"
#include "../containers.h"
#include "../session.h"
#include "../utils.h"
#include <stdint.h>

static int check_result(JNIEnv *jenv, int result)
{
    switch (result) {
    case GA_OK:
        break;
    default: /* GA_ERROR */
        SWIG_JavaThrowException(jenv, SWIG_JavaRuntimeException, "Failed");
        break;
    }
    return result;
}

/* Use a static class to hold our opaque pointers */
#define OBJ_CLASS "com/blockstream/libgreenaddress/GASDK$Obj"

/* Create and return a java object to hold an opaque pointer */
static jobject create_obj(JNIEnv *jenv, void *p, int id) {
    jclass clazz;
    jmethodID ctor;

    if (!(clazz = (*jenv)->FindClass(jenv, OBJ_CLASS)))
        return NULL;
    if (!(ctor = (*jenv)->GetMethodID(jenv, clazz, "<init>", "(JI)V")))
        return NULL;
    return (*jenv)->NewObject(jenv, clazz, ctor, (jlong)(uintptr_t)p, id);
}

/* Fetch an opaque pointer from a java object */
static void *get_obj(JNIEnv *jenv, jobject obj, int id) {
    jclass clazz;
    jmethodID getter;
    void *ret;

    if (!obj || !(clazz = (*jenv)->GetObjectClass(jenv, obj)))
        return NULL;
    getter = (*jenv)->GetMethodID(jenv, clazz, "get_id", "()I");
    if (!getter || (*jenv)->CallIntMethod(jenv, obj, getter) != id ||
        (*jenv)->ExceptionOccurred(jenv))
        return NULL;
    getter = (*jenv)->GetMethodID(jenv, clazz, "get", "()J");
    if (!getter)
        return NULL;
    ret = (void *)(uintptr_t)((*jenv)->CallLongMethod(jenv, obj, getter));
    return (*jenv)->ExceptionOccurred(jenv) ? NULL : ret;
}

static void* get_obj_or_throw(JNIEnv *jenv, jobject obj, int id, const char *name) {
    void *ret = get_obj(jenv, obj, id);
    if (!ret)
        SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, name);
    return ret;
}

static unsigned char* malloc_or_throw(JNIEnv *jenv, size_t len) {
    unsigned char *p = (unsigned char *)malloc(len);
    if (!p) {
        SWIG_JavaThrowException(jenv, SWIG_JavaOutOfMemoryError, "Out of memory");
    }
    return p;
}

static jbyteArray create_array(JNIEnv *jenv, const unsigned char* p, size_t len) {
    jbyteArray ret = (*jenv)->NewByteArray(jenv, len);
    if (ret) {
        (*jenv)->SetByteArrayRegion(jenv, ret, 0, len, (const jbyte*)p);
    }
    return ret;
}

%}

%javaconst(1);
%ignore GA_destroy_dict;
%ignore GA_destroy_string;

%pragma(java) jniclasscode=%{
    private static boolean loadLibrary() {
        try {
            System.loadLibrary("greenaddress");
            return true;
        } catch (final UnsatisfiedLinkError e) {
            System.err.println("Native code library failed to load.\n" + e);
            return false;
        }
    }

    private static final boolean enabled = loadLibrary();
    public static boolean isEnabled() {
        return enabled;
    }

    static final class Obj {
        private final transient long ptr;
        private final int id;
        private Obj(final long ptr, final int id) { this.ptr = ptr; this.id = id; }
        private long get() { return ptr; }
        private int get_id() { return id; }
    }
%}
%pragma(java) jniclassimports=%{
    import java.util.Date;
%}

/* Raise an exception whenever a function fails */
%exception {
    $action
    check_result(jenv, result);
}

/* Don't use our int return value except for exception checking */
%typemap(out) int %{
%}
%typemap(in,noblock=1,numinputs=0) char** output(char* temp = 0) {
      $1 = &temp;
}
%typemap(argout, noblock=1) (char** output) {
    if ($1) {
        $result = (*jenv)->NewStringUTF(jenv, *$1);
        GA_destroy_string(*$1);
    } else {
        $result = NULL;
    }
}
%define %java_opaque_struct(NAME, ID)
%typemap(in, numinputs=0) struct NAME** (struct NAME* w) {
    w = 0; $1 = ($1_ltype)&w;
}
%typemap(argout) struct NAME** {
    if (*$1) {
        $result = create_obj(jenv, *$1, ID);
    }
}
%typemap(in) struct NAME* {
    $1 = (struct NAME*) get_obj_or_throw(jenv, $input, ID, "NAME");
    if (!$1) {
        return $null;
    }
}
%typemap(jtype) struct NAME* "Object"
%typemap(jni) struct NAME* "jobject"
%enddef

/* Change a functions return type to match its output type mapping */
%define %return_decls(FUNC, JTYPE, JNITYPE)
%typemap(jstype) int FUNC "JTYPE"
%typemap(jtype) int FUNC "JTYPE"
%typemap(jni) int FUNC "JNITYPE"
%rename("%(strip:[GA_])s") FUNC;
%enddef

%define %returns_void__(FUNC)
%return_decls(FUNC, void, void)
%enddef
%define %returns_struct(FUNC, STRUCT)
%return_decls(FUNC, Object, jobject)
%enddef
%define %returns_string(FUNC)
%return_decls(FUNC, String, jstring)
%enddef
%define %returns_array_(FUNC, ARRAYARG, LENARG, LEN)
%return_decls(FUNC, byte[], jbyteArray)
%exception FUNC {
    int skip = 0;
    jresult = NULL;
    if (!jarg ## ARRAYARG) {
        arg ## LENARG = LEN;
        arg ## ARRAYARG = malloc_or_throw(jenv, LEN);
        if (!arg ## ARRAYARG) {
            skip = 1; /* Exception set by malloc_or_throw */
        }
    }
    if (!skip) {
        $action
        if (check_result(jenv, result) == GA_OK && !jarg ## ARRAYARG) {
            jresult = create_array(jenv, arg ## ARRAYARG, LEN);
        }
        if (!jarg ## ARRAYARG) {
            // wally_bzero(arg ## ARRAYARG, LEN);
            free(arg ## ARRAYARG);
        }
    }
}
%enddef

%java_opaque_struct(GA_session, 1)
%java_opaque_struct(GA_tx_list, 2)
%java_opaque_struct(GA_dict, 3)

%returns_struct(GA_create_session, GA_session)
%returns_void__(GA_destroy_session)
%returns_void__(GA_connect)
%returns_void__(GA_register_user)
%returns_void__(GA_login)
%returns_struct(GA_get_tx_list, GA_tx_list)
%returns_void__(GA_destroy_tx_list)
%returns_string(GA_convert_tx_list_to_json)
%returns_struct(GA_convert_tx_list_path_to_dict, GA_dict)
%returns_string(GA_convert_tx_list_path_to_string)
%returns_string(GA_get_receive_addresss)
%returns_string(GA_tx_view_get_received_on)
%returns_string(GA_tx_view_get_counterparty)
%returns_string(GA_tx_view_get_hash)
%returns_string(GA_tx_view_get_double_spent_by)
%returns_string(GA_convert_balance_to_json)
%returns_array_(GA_get_random_bytes, 2, 3, jarg1)
%returns_string(GA_generate_mnemonic)

%include "../common.h"
%include "../containers.h"
%include "../session.h"
%include "../utils.h"
