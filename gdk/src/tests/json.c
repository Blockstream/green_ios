#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "json.h"

// Poor man's json parsing
char* json_extract(const char* json, const char* field_name)
{
    static const char* format = "\"%s\":";
    char* buffer = malloc(strlen(field_name) + strlen("\"\":") + 1);
    sprintf(buffer, format, field_name);

    char* retval = 0;
    const char* start = strstr(json, buffer);
    if (start) {
        start += strlen(buffer);
        const char* end = strstr(start, ",");
        if (end) {
            size_t len = end - start;
            retval = malloc(len + 1);
            strncpy(retval, start, len);
            retval[len] = '\0';
        }
    }
    free(buffer);
    return retval;
}
