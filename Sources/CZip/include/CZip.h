#include <stddef.h>
#include <stdint.h>
int zms_inflate(const uint8_t *src, size_t src_len, uint8_t *dst, size_t dst_len);
uint32_t zms_crc(const uint8_t *data, size_t len);
