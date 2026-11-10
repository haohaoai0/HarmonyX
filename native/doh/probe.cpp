// Device-side smoke probe for the exact native library linked into the HAP.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
extern "C" {
struct NativeResponse { char *metadata; uint8_t *body; size_t length; };
void hx_http_register(uint64_t);
void hx_http_forget(uint64_t);
NativeResponse *hx_http_request(const char *, const uint8_t *, size_t,
    void (*)(void *, int32_t, const char *, const uint8_t *, size_t), void *);
void hx_http_free(NativeResponse *);
}
int main(int argc, char **argv) {
    const std::string endpoint = argc > 1 ? argv[1] : "https://edge.1molchuan.top/linuxdo";
    const std::string url = argc > 2 ? argv[2] : "https://x.com/robots.txt";
    const std::string input = "{\"id\":1,\"endpoint\":\"" + endpoint + "\",\"url\":\"" + url +
        "\",\"method\":\"GET\",\"headers\":{},\"maxLimit\":5242880,\"connectTimeout\":10000,\"readTimeout\":15000}";
    hx_http_register(1);
    NativeResponse *result = hx_http_request(input.c_str(), nullptr, 0, nullptr, nullptr);
    if (!result) return 2;
    std::printf("%s\nbody_bytes=%zu\n", result->metadata, result->length);
    if (result->length) std::printf("%.*s\n", static_cast<int>(result->length > 120 ? 120 : result->length), result->body);
    int code = std::strstr(result->metadata, "\"ok\":true") ? 0 : 1;
    hx_http_free(result);
    hx_http_forget(1);
    return code;
}
