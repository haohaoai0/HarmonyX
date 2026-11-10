#include "napi/native_api.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <thread>
#include <vector>

extern "C" {
struct NativeResponse { char *metadata; uint8_t *body; size_t length; };
using Emit = void (*)(void *, int32_t, const char *, const uint8_t *, size_t);
void hx_http_register(uint64_t);
void hx_http_cancel(uint64_t);
void hx_http_forget(uint64_t);
NativeResponse *hx_http_request(const char *, const uint8_t *, size_t, Emit, void *);
void hx_http_free(NativeResponse *);
}

namespace {
struct Event { int32_t kind; std::string metadata; std::vector<uint8_t> bytes; };
struct Work {
    uint64_t id = 0;
    napi_deferred deferred = nullptr;
    napi_threadsafe_function events = nullptr;
    std::string metadata;
    std::vector<uint8_t> body;
    NativeResponse *response = nullptr;
    ~Work() {
        std::fill(metadata.begin(), metadata.end(), '\0');
        std::fill(body.begin(), body.end(), 0);
        hx_http_free(response);
        hx_http_forget(id);
    }
};
bool ReadString(napi_env env, napi_value value, std::string &out) {
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok || size > 1024 * 1024) return false;
    out.resize(size + 1);
    if (napi_get_value_string_utf8(env, value, out.data(), out.size(), &size) != napi_ok) return false;
    out.resize(size);
    return true;
}
void OnEvent(napi_env env, napi_value callback, void *, void *data) {
    std::unique_ptr<Event> event(static_cast<Event *>(data));
    if (!env || !callback) return;
    napi_value args[3], receiver, ignored;
    napi_create_int32(env, event->kind, &args[0]);
    napi_create_string_utf8(env, event->metadata.c_str(), event->metadata.size(), &args[1]);
    void *buffer = nullptr;
    napi_create_arraybuffer(env, event->bytes.size(), &buffer, &args[2]);
    if (!event->bytes.empty()) std::memcpy(buffer, event->bytes.data(), event->bytes.size());
    napi_get_undefined(env, &receiver);
    napi_call_function(env, receiver, callback, 3, args, &ignored);
    // A listener exception must not leave the native promise unsettled.
    bool pending = false;
    napi_is_exception_pending(env, &pending);
    if (pending) napi_get_and_clear_last_exception(env, &ignored);
}
void EmitEvent(void *context, int32_t kind, const char *metadata, const uint8_t *bytes, size_t length) {
    Work *work = static_cast<Work *>(context);
    std::unique_ptr<Event> event(new Event{kind, metadata ? metadata : "null", {}});
    if (length) event->bytes.assign(bytes, bytes + length);
    // Bound the queue: long downloads cannot accumulate unbounded chunk copies
    // when the ArkTS thread is busy rendering.
    if (napi_call_threadsafe_function(work->events, event.get(), napi_tsfn_blocking) == napi_ok) event.release();
}
void Finalize(napi_env env, void *data, void *) {
    std::unique_ptr<Work> work(static_cast<Work *>(data));
    if (!env) return;
    napi_value value, metadata, body;
    napi_create_object(env, &value);
    const char *text = work->response ? work->response->metadata : "{\"ok\":false,\"error\":\"Native HTTP failure\",\"code\":2300999}";
    napi_create_string_utf8(env, text, NAPI_AUTO_LENGTH, &metadata);
    void *bytes = nullptr;
    size_t length = work->response ? work->response->length : 0;
    napi_create_arraybuffer(env, length, &bytes, &body);
    if (length) std::memcpy(bytes, work->response->body, length);
    napi_set_named_property(env, value, "metadata", metadata);
    napi_set_named_property(env, value, "body", body);
    // TSFN finalization happens after all queued headers/data/progress events.
    // The streaming promise therefore cannot settle before the last chunk.
    napi_resolve_deferred(env, work->deferred, value);
}
napi_value Request(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4], promise, name;
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::unique_ptr<Work> work(new Work());
    double id = 0;
    void *bytes = nullptr;
    size_t length = 0;
    napi_valuetype callbackType;
    if (argc != 4 || napi_get_value_double(env, args[0], &id) != napi_ok || !std::isfinite(id) ||
        id < 1 || id > 9007199254740991.0 || std::floor(id) != id ||
        !ReadString(env, args[1], work->metadata) ||
        napi_get_arraybuffer_info(env, args[2], &bytes, &length) != napi_ok || length > 100 * 1024 * 1024 ||
        napi_typeof(env, args[3], &callbackType) != napi_ok || callbackType != napi_function) {
        napi_throw_type_error(env, nullptr, "request requires id, metadata, ArrayBuffer and event callback");
        return nullptr;
    }
    work->id = static_cast<uint64_t>(id);
    if (length) work->body.assign(static_cast<uint8_t *>(bytes), static_cast<uint8_t *>(bytes) + length);
    napi_create_promise(env, &work->deferred, &promise);
    napi_create_string_utf8(env, "HarmonyXDoH", NAPI_AUTO_LENGTH, &name);
    if (napi_create_threadsafe_function(env, args[3], nullptr, name, 32, 1, work.get(), Finalize,
        work.get(), OnEvent, &work->events) != napi_ok) {
        napi_throw_error(env, nullptr, "Unable to initialize HTTP task");
        return nullptr;
    }
    hx_http_register(work->id);
    Work *task = work.release();
    try {
        std::thread([task]() {
            task->response = hx_http_request(task->metadata.c_str(), task->body.data(), task->body.size(), EmitEvent, task);
            napi_release_threadsafe_function(task->events, napi_tsfn_release);
        }).detach();
    } catch (...) {
        hx_http_cancel(task->id);
        napi_release_threadsafe_function(task->events, napi_tsfn_release);
    }
    return promise;
}
napi_value Cancel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value arg, result;
    double id = 0;
    napi_get_cb_info(env, info, &argc, &arg, nullptr, nullptr);
    if (argc == 1 && napi_get_value_double(env, arg, &id) == napi_ok && std::isfinite(id) && id >= 1 && id <= 9007199254740991.0) {
        hx_http_cancel(static_cast<uint64_t>(id));
    }
    napi_get_undefined(env, &result);
    return result;
}
napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"request", nullptr, Request, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cancel", nullptr, Cancel, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, 2, properties);
    return exports;
}
napi_module module = {1, 0, nullptr, Init, "harmonyx_doh", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void RegisterDoH() { napi_module_register(&module); }
