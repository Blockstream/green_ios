%module GASDK
%{
#include "../../include/common.h"
#include "../../include/containers.h"
#include "../../include/twofactor.h"
#include "../../include/session.h"
#include "../../include/utils.h"
#include <stdint.h>
#include <limits.h>


static JavaVM* gdk_jvm;

static const jint JNI_VERSIONS[5] = {
    JNI_VERSION_1_8, JNI_VERSION_1_6, JNI_VERSION_1_4, JNI_VERSION_1_2, JNI_VERSION_1_1
};

static const char* NOTIFY_METHOD_NAME = "callNotificationHandler";
static const char* NOTIFY_METHOD_ARGS = "(Ljava/lang/Object;Ljava/lang/Object;)V";
static const char* OBJ_CLASS  = "com/blockstream/libgreenaddress/GASDK$Obj";
static const char* SDK_CLASS  = "com/blockstream/libgreenaddress/GASDK";

#define GA_SDK_SWIG_SESSION_ID 1
#define GA_SDK_SWIG_TWOFACTOR_CALL_ID 2

static unsigned char* malloc_or_throw(JNIEnv *jenv, size_t len) {
    unsigned char *p = (unsigned char *)malloc(len);
    if (!p) {
        SWIG_JavaThrowException(jenv, SWIG_JavaOutOfMemoryError, "Out of memory");
    }
    return p;
}

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

static uint32_t uint32_cast(JNIEnv *jenv, jlong value) {
    if (value < 0 || value > UINT_MAX)
        SWIG_JavaThrowException(jenv, SWIG_JavaIndexOutOfBoundsException, "Invalid uint32_t");
    return (uint32_t)value;
}

/* Create and return a native json object from GA_json */
static jobject create_json(JNIEnv *jenv, void *p, int destroy) {
    char* json_cstring = NULL;
    jstring json_string;
    jobject json_obj;
    jclass clazz;
    jmethodID convert_fn;

    if (GA_convert_json_to_string((GA_json *)p, &json_cstring) != GA_OK) {
        SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "GA_json");
        return NULL;
    }

    json_string = (*jenv)->NewStringUTF(jenv, json_cstring);
    GA_destroy_string(json_cstring);

    // FIXME: Cache FindClass/GetStaticMethodID in global references for efficiency
    // See https://www.fer.unizg.hr/_download/repository/jni.pdf page 63 for details
    if (!json_string)
        return NULL;
    if (!(clazz = (*jenv)->FindClass(jenv, SDK_CLASS)))
        return NULL;
    if (!(convert_fn = (*jenv)->GetStaticMethodID(jenv, clazz, "toJSONObject", "(Ljava/lang/String;)Ljava/lang/Object;")))
        return NULL;
    if (!(json_obj = (*jenv)->CallStaticObjectMethod(jenv, clazz, convert_fn, json_string)))
        return NULL;
    if (destroy)
        GA_destroy_json((GA_json *)p);
    return json_obj;
}

/* Create and return a GA_json from a native json object */
static void* get_json_or_throw(JNIEnv *jenv, jobject json_obj) {
    const char* json_cstring;
    GA_json* json = NULL;
    jstring json_string;
    jclass clazz;
    jmethodID convert_fn;

    if (!(clazz = (*jenv)->FindClass(jenv, SDK_CLASS)))
        return NULL;
    if (!(convert_fn = (*jenv)->GetStaticMethodID(jenv, clazz, "toJSONString", "(Ljava/lang/Object;)Ljava/lang/String;")))
        return NULL;
    if (!(json_string = (*jenv)->CallStaticObjectMethod(jenv, clazz, convert_fn, json_obj)))
        return NULL;
    if (!(json_cstring = (*jenv)->GetStringUTFChars(jenv, json_string, NULL)))
        return NULL;
    GA_convert_string_to_json(json_cstring, &json);
    (*jenv)->ReleaseStringUTFChars(jenv, json_string, json_cstring);
    if (!json)
        SWIG_JavaThrowException(jenv, SWIG_JavaIllegalArgumentException, "GA_json");
    return json;
}

typedef struct notification_context
{
    struct GA_session* m_session;
    jobject m_session_obj;
} notify_t;

// Call any registered notification handler
static void notification_handler(void* context_p, const GA_json* details)
{
    JNIEnv *jenv;
    notify_t* n = (notify_t*) context_p;
    jobject json_obj;
    jclass clazz;
    jmethodID handler_fn;
    int status;
    size_t i;

    if (!gdk_jvm || !context_p || !n->m_session)
        return; // Called after un-registering

    for (i = 0; i < sizeof(JNI_VERSIONS)/sizeof(JNI_VERSIONS[0]); ++i) {
        status = (*gdk_jvm)->GetEnv(gdk_jvm, (void**) &jenv, JNI_VERSIONS[i]);
        if (status != JNI_EVERSION)
            break;
    }

    if (status == JNI_EDETACHED) {
        if ((*gdk_jvm)->AttachCurrentThread(gdk_jvm, (void**) &jenv, NULL))
            return;
    } else if (status != JNI_OK)
        return;

    if (!details) {
        // Un-registering
        (*jenv)->DeleteGlobalRef(jenv, n->m_session_obj);
        memset(n, 0, sizeof(*n));
        free(n);
        goto end;
    }

    if (!(json_obj = create_json(jenv, (void *)details, 0)))
        goto end;
    if (!(clazz = (*jenv)->FindClass(jenv, SDK_CLASS)))
        goto end;
    if (!(handler_fn = (*jenv)->GetStaticMethodID(jenv, clazz, NOTIFY_METHOD_NAME, NOTIFY_METHOD_ARGS)))
        goto end;
    (*jenv)->CallStaticVoidMethod(jenv, clazz, handler_fn, n->m_session_obj, json_obj);

end:
    if (status == JNI_EDETACHED)
        (*gdk_jvm)->DetachCurrentThread(gdk_jvm);
}

/* Create and return a java object to hold an opaque pointer */
static jobject create_obj(JNIEnv *jenv, void *p, int id) {
    jclass clazz;
    jmethodID ctor;
    jobject obj = 0;

    if (!gdk_jvm) {
        // Cache our JVM instance for callbacks before we create our
        // first object, and therefore before any callback can fire
        if ((*jenv)->GetJavaVM(jenv, &gdk_jvm))
            return NULL;
    }

    if (!(clazz = (*jenv)->FindClass(jenv, OBJ_CLASS)))
        return NULL;
    if (!(ctor = (*jenv)->GetMethodID(jenv, clazz, "<init>", "(JI)V")))
        return NULL;
    if (!(obj = (*jenv)->NewObject(jenv, clazz, ctor, (jlong)(uintptr_t)p, id)))
        return NULL;

    if (id == GA_SDK_SWIG_SESSION_ID) {
        // Set the notification handler for the session after creating it
        notify_t* n = (notify_t*)malloc_or_throw(jenv, sizeof(notify_t));
        if (!n)
            return NULL;
        n->m_session = (struct GA_session*) p;
        n->m_session_obj = (*jenv)->NewGlobalRef(jenv, obj);
        if (!n->m_session_obj) {
            free(n);
            return NULL;
        }
        // FIXME: Error handling if this call fails
        GA_set_notification_handler(n->m_session, notification_handler, n);
    }
    return obj;
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

static jbyteArray create_array(JNIEnv *jenv, const unsigned char* p, size_t len) {
    jbyteArray ret = (*jenv)->NewByteArray(jenv, len);
    if (ret) {
        (*jenv)->SetByteArrayRegion(jenv, ret, 0, len, (const jbyte*)p);
    }
    return ret;
}

%}

%javaconst(1);
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

    // JSON conversion
    public interface JSONConverter {
       Object toJSONObject(final String jsonString);
       String toJSONString(final Object jsonObject);
    }

    private static JSONConverter mJSONConverter = null;

    public static void setJSONConverter(final JSONConverter jsonConverter) {
        mJSONConverter = jsonConverter;
    }

    private static Object toJSONObject(final String jsonString) {
        if (mJSONConverter == null)
            return (Object) jsonString;
        return mJSONConverter.toJSONObject(jsonString);
    }

    private static String toJSONString(final Object jsonObject) {
        if (mJSONConverter == null)
            return (String) jsonObject;
        return mJSONConverter.toJSONString(jsonObject);
    }

    // Notifications
    public interface NotificationHandler {
       void onNewNofification(final Object session, final Object jsonObject);
    }

    private static NotificationHandler mNotificationHandler = null;

    public static void setNotificationHandler(final NotificationHandler notificationHandler) {
        mNotificationHandler = notificationHandler;
    }

    private static void callNotificationHandler(final Object session, final Object jsonObject) {
        if (mNotificationHandler != null)
            mNotificationHandler.onNewNofification(session, jsonObject);
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
/* Output strings are converted to native Java strings and returned */
%typemap(in,noblock=1,numinputs=0) char **(char *temp = 0) {
    $1 = &temp;
}
%typemap(argout,noblock=1) (char **) {
    if ($1) {
        $result = (*jenv)->NewStringUTF(jenv, *$1);
        GA_destroy_string(*$1);
    } else
        $result = NULL;
}
/* uint32_t input arguments are taken as longs and cast with range checking */
%typemap(in) uint32_t {
    $1 = uint32_cast(jenv, $input);
}

/* uint64_t input arguments are taken as longs and cast unchecked. This means
 * callers need to take care with treating negative values correctly */
%typemap(in) uint64_t {
    $1 = (uint64_t)($input);
}

/* JSON */
%typemap(in, numinputs=0) GA_json** (GA_json* w) {
    w = 0; $1 = ($1_ltype)&w;
}
%typemap(argout) GA_json** {
    if (*$1) {
        $result = create_json(jenv, *$1, 1);
    }
}
%typemap(in) GA_json* {
    $1 = (GA_json*) get_json_or_throw(jenv, $input);
    if (!$1) {
        return $null;
    }
}
%typemap(jtype) GA_json* "Object"
%typemap(jni) GA_json* "jobject"

/* Opaque structures */
%define %java_struct(NAME, ID)
%typemap(in, numinputs=0) NAME** (NAME* w) {
    w = 0; $1 = ($1_ltype)&w;
}
%typemap(argout) NAME** {
    if (*$1) {
        $result = create_obj(jenv, *$1, ID);
    }
}
%typemap(in) NAME* {
    $1 = (NAME*) get_obj_or_throw(jenv, $input, ID, "NAME");
    if (!$1) {
        return $null;
    }
}
%typemap(jtype) NAME* "Object"
%typemap(jni) NAME* "jobject"
%enddef

%define %java_opaque_struct(NAME, ID)
%java_struct(struct NAME, ID)
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

%java_opaque_struct(GA_session, GA_SDK_SWIG_SESSION_ID)
%java_opaque_struct(GA_twofactor_call, GA_SDK_SWIG_TWOFACTOR_CALL_ID)

%returns_void__(GA_ack_system_message)
%returns_void__(GA_change_settings_pricing_source)
%returns_void__(GA_change_settings_tx_limits)
%returns_void__(GA_connect)
%returns_void__(GA_connect_with_proxy)
%returns_struct(GA_convert_amount, GA_json)
%returns_string(GA_convert_json_to_string)
%returns_string(GA_convert_json_value_to_string)
%returns_struct(GA_convert_string_to_json, GA_json)
%returns_struct(GA_create_session, GA_session)
%returns_struct(GA_create_transaction, GA_json)
%returns_struct(GA_create_subaccount, GA_json)
%returns_struct(GA_decrypt, GA_json)
%returns_void__(GA_destroy_session)
%returns_void__(GA_destroy_twofactor_call)
%returns_void__(GA_destroy_json)
%returns_void__(GA_disconnect)
%returns_struct(GA_encrypt, GA_json)
%returns_string(GA_generate_mnemonic)
%returns_struct(GA_get_available_currencies, GA_json)
%returns_struct(GA_get_balance, GA_json)
%returns_struct(GA_get_fee_estimates, GA_json)
%returns_string(GA_get_mnemonic_passphrase)
%returns_array_(GA_get_random_bytes, 2, 3, jarg1)
%returns_struct(GA_get_transaction_details, GA_json)
%returns_struct(GA_get_subaccounts, GA_json)
%returns_string(GA_get_system_message)
%returns_struct(GA_get_transactions, GA_json)
%returns_struct(GA_get_twofactor_config, GA_json)
%returns_struct(GA_get_unspent_outputs, GA_json)
%returns_struct(GA_get_unspent_outputs_for_private_key, GA_json)
%returns_string(GA_get_receive_address)
%returns_void__(GA_login)
%returns_void__(GA_login_watch_only)
%returns_void__(GA_login_with_pin)
%returns_void__(GA_register_user)
%returns_struct(GA_remove_account, GA_twofactor_call)
%returns_void__(GA_send_nlocktimes)
%returns_struct(GA_send_transaction, GA_twofactor_call)
%returns_struct(GA_set_pin, GA_json)
%returns_void__(GA_set_transaction_memo)
%returns_struct(GA_sign_transaction, GA_json)
%returns_void__(GA_twofactor_call)
/*%returns_struct(GA_twofactor_change_tx_limits, GA_twofactor_call)*/
%returns_struct(GA_change_settings_twofactor, GA_twofactor_call)
%returns_struct(GA_twofactor_get_status, GA_json)
%returns_void__(GA_twofactor_request_code)
%returns_void__(GA_twofactor_resolve_code)

/* TODO
GA_convert_json_value_to_bool
GA_convert_json_value_to_string
GA_convert_json_value_to_uint32
GA_convert_json_value_to_uint64
GA_destroy_string
GA_subscribe_to_topic_as_json
GA_validate_mnemonic
*/

%include "../include/common.h"
%include "../include/containers.h"
%include "../include/session.h"
%include "../include/utils.h"
%include "../include/twofactor.h"
