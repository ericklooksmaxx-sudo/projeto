#include "my_utils.h"

#include <stdio.h>
#include <string.h>

char *my_strncpy(char *dest, const char *src, size_t bufSize) {
    if (dest == NULL || bufSize == 0) return dest;
    snprintf(dest, bufSize, "%s", src != NULL ? src : "");
    return dest;
}

int _string_startsWith(const char* src, const char* prefix) {
    while (1) {
        if (*prefix == 0) return 0;
        if (*src != *prefix) return -1;
        if (*src == 0) return -1;
        src++;
        prefix++;
    }
    return -1;
}

int _string_endWith(const char* src, char ch) {
    if (*src == 0) return -1;
    if (src[strlen(src) - 1] == ch) return 0;
    return -1;
}
