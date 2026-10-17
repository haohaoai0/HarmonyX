#include "napi/native_api.h"
#include <mutex>
#include <string>
#include <memory>

extern "C" {
void *hx_chat_new();
void hx_chat_free(void *);
char *hx_chat_call(void *, const char *, const char *);
void hx_chat_free_string(char *);
}

namespace {
std::mutex chatMutex;
void *chatSession = nullptr;
struct Work {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string method, input, output;
    ~Work() { std::fill(input.begin(), input.end(), '\0'); }
};

bool ReadString(napi_env env, napi_value value, std::string &out) {
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok || size > 16 * 1024 * 1024) return false;
    out.resize(size + 1);
    if (napi_get_value_string_utf8(env, value, out.data(), out.size(), &size) != napi_ok) return false;
    out.resize(size);
    return true;
}

void Execute(napi_env, void *data) {
    Work *w = static_cast<Work *>(data);
    std::lock_guard<std::mutex> lock(chatMutex);
    if (w->method == "reset") {
        if (chatSession) hx_chat_free(chatSession);
        chatSession = hx_chat_new();
        w->output = chatSession ? "{\"ok\":true,\"data\":{}}" : "{\"ok\":false,\"error\":\"native_initialization_failed\"}";
        return;
    }
    if (!chatSession) chatSession = hx_chat_new();
    char *value = hx_chat_call(chatSession, w->method.c_str(), w->input.c_str());
    w->output = value ? value : "{\"ok\":false,\"error\":\"native_failure\"}";
    hx_chat_free_string(value);
    std::fill(w->input.begin(), w->input.end(), '\0');
}

void Complete(napi_env env, napi_status status, void *data) {
    std::unique_ptr<Work> w(static_cast<Work *>(data));
    napi_value value;
    if (status == napi_ok) {
        napi_create_string_utf8(env, w->output.c_str(), w->output.size(), &value);
        napi_resolve_deferred(env, w->deferred, value);
    } else {
        napi_create_string_utf8(env, "native_task_failed", NAPI_AUTO_LENGTH, &value);
        napi_reject_deferred(env, w->deferred, value);
    }
    napi_delete_async_work(env, w->work);
}

napi_value Invoke(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2], promise, name;
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::unique_ptr<Work> w(new Work());
    if (argc != 2 || !ReadString(env, args[0], w->method) || !ReadString(env, args[1], w->input)) {
        napi_throw_type_error(env, nullptr, "invoke requires method and JSON strings");
        return nullptr;
    }
    napi_create_promise(env, &w->deferred, &promise);
    napi_create_string_utf8(env, "HarmonyXChat", NAPI_AUTO_LENGTH, &name);
    if (napi_create_async_work(env, nullptr, name, Execute, Complete, w.get(), &w->work) != napi_ok ||
        napi_queue_async_work(env, w->work) != napi_ok) {
        napi_throw_error(env, nullptr, "Unable to queue chat task");
        return nullptr;
    }
    w.release();
    return promise;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor props[] = {{"invoke", nullptr, Invoke, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, 1, props);
    return exports;
}
napi_module module = {1, 0, nullptr, Init, "harmonyx_chat", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void RegisterChat() { napi_module_register(&module); }

