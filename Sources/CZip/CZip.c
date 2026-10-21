#include "CZip.h"
#include <zlib.h>
int zms_inflate(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_len) {
    z_stream s = {0};
    if (src_len > UINT32_MAX || dst_len > UINT32_MAX) return 0;
    s.next_in = (Bytef *)src; s.avail_in = (uInt)src_len;
    s.next_out = dst; s.avail_out = (uInt)dst_len;
    if (inflateInit2(&s, -MAX_WBITS) != Z_OK) return 0;
    int result = inflate(&s, Z_FINISH);
    int ok = result == Z_STREAM_END && s.total_out == dst_len && s.total_in == src_len;
    inflateEnd(&s); return ok;
}
uint32_t zms_crc(const uint8_t *data, size_t len) { return (uint32_t)crc32(0, data, (uInt)len); }
