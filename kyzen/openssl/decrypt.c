#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "openssl/evp.h"
#include <errno.h>

#ifdef _WIN32
#include <windows.h>
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

#define KEY_LEN 32
#define IV_LEN 16
#define BUF_SIZE (1024 * 16)  // buffer

#define CIPHER_AES_256_CFB8 0
#define CIPHER_AES_CTR      1

typedef struct {
    int success; // 1 for success, 0 for failure
    char* error_message; // NULL if no error
} FileOperationResult;

// Helper function to create error result
FileOperationResult create_error_result(const char* message) {
    FileOperationResult result = {0, NULL};
    if (message) {
        result.error_message = strdup(message);
    }
    return result;
}

// Helper function to create success result
FileOperationResult create_success_result() {
    FileOperationResult result = {1, NULL};
    return result;
}

// helper to build a formatted error string
static FileOperationResult create_errno_error(const char* context, int err_code) {
    char msg[512];
    snprintf(msg, sizeof(msg), "%s: [errno %d] %s", context, err_code, strerror(err_code));
    return create_error_result(msg);
}

// Free memory allocated for result
EXPORT void free_file_operation_result(FileOperationResult* result) {
    if (result && result->error_message) {
        free(result->error_message);
    }
}

int is_hex_string(const char* str, size_t expected_len) {
    if (strlen(str) != expected_len) return 0;
    
    for (size_t i = 0; i < expected_len; i++) {
        char c = str[i];
        if (!((c >= '0' && c <= '9') || 
              (c >= 'a' && c <= 'f') || 
              (c >= 'A' && c <= 'F'))) {
            return 0;
        }
    }
    return 1;
}

// Convert hex string to bytes
// Hex keys are used for entitlement decryption for safety.
// This is done because there's a chance that the entKey may contain byte value 0 
// which acts as a null terminator in C strings and cut off the key. 
void hex_to_bytes(const char* hex_str, unsigned char* bytes, size_t byte_len) {
    for (size_t i = 0; i < byte_len; i++) {
        sscanf(hex_str + (i * 2), "%2hhx", &bytes[i]);
    }
}

EXPORT FileOperationResult decrypt_file_ex(
    const char* input_path,
    const char* output_path,
    const char* key_str,
    int cipher_mode
) {
    unsigned char key[KEY_LEN];
    unsigned char iv[IV_LEN];
    
    // Check if it's a hex string (64 char)
    if (is_hex_string(key_str, KEY_LEN * 2)) {
        hex_to_bytes(key_str, key, KEY_LEN);
        memcpy(iv, key, IV_LEN);
    } 
    else if (strlen(key_str) >= KEY_LEN) {
        memcpy(key, key_str, KEY_LEN);
        memcpy(iv, key_str, IV_LEN);
    } 
    else {
        return create_error_result("Key must be either 32 characters or 64 hex characters");
    }

    const EVP_CIPHER* cipher = NULL;
    if (cipher_mode == CIPHER_AES_CTR) {
        cipher = EVP_aes_256_ctr();
    } else if (cipher_mode == CIPHER_AES_256_CFB8) {
        cipher = EVP_aes_256_cfb8();
    } else {
        return create_error_result("Unsupported cipher mode");
    }

    FILE* input_file = NULL;

    // this is a specific fix for Windows path handling, sometimes some files may contain RLM unicode
#ifdef _WIN32
    // Windows Unicode file handling
    wchar_t input_path_wide[MAX_PATH];
    wchar_t output_path_wide[MAX_PATH];
    
    // Convert UTF-8 to UTF-16
    int input_convert_result = MultiByteToWideChar(CP_UTF8, 0, input_path, -1, input_path_wide, MAX_PATH);
    if (input_convert_result == 0) {
        return create_error_result("Failed to convert input path to Unicode");
    }
    
    input_file = _wfopen(input_path_wide, L"rb");
#else
    input_file = fopen(input_path, "rb");
#endif

    if (!input_file) {
        return create_errno_error("Failed to open input file", errno);
    }

    // Get file size
    fseek(input_file, 0, SEEK_END);
    long file_size = ftell(input_file);
    fseek(input_file, 0, SEEK_SET);

    // skip empty files
    if (file_size <= 0) {
        fclose(input_file);
        return create_success_result();
    }

    // Read file content
    unsigned char* file_data = malloc(file_size);
    if (!file_data) {
        fclose(input_file);
        return create_error_result("Memory allocation failed");
    }

    size_t bytes_read = fread(file_data, 1, file_size, input_file);
    fclose(input_file);

    if (bytes_read != file_size) {
        free(file_data);
        return create_error_result("Failed to read input file");
    }

    int should_skip_header = 0;
    
    if (file_size >= 17) { 

        uint32_t version = 0;
        uint32_t magic = 0;
        memcpy(&version, file_data, sizeof(uint32_t));
        memcpy(&magic, file_data + 4, sizeof(uint32_t));
        
        // very magically number to check
        if (version == 0 && magic == 0x9BCFB9FC) {
            should_skip_header = 1;
        }
    }

    // Skip header
    unsigned char* data_to_decrypt = file_data;
    int data_length = file_size;
    if (should_skip_header && file_size >= 0x100) {
        data_to_decrypt += 0x100;
        data_length -= 0x100;
    }

    // Set up decryption
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        free(file_data);
        return create_error_result("Failed to create cipher context");
    }

    if (1 != EVP_DecryptInit_ex(ctx, cipher, NULL, key, iv)) {
        free(file_data);
        EVP_CIPHER_CTX_free(ctx);
        return create_error_result("Decryption initialization failed");
    }

    // Decrypt in-place, (AES-CFB8 is a stream mode)
    int out_len;
    if (1 != EVP_DecryptUpdate(ctx, data_to_decrypt, &out_len, data_to_decrypt, data_length)) {
        free(file_data);
        EVP_CIPHER_CTX_free(ctx);
        return create_error_result("Decryption failed");
    }

    // Clean up cipher context
    EVP_CIPHER_CTX_free(ctx);

    FILE* output_file = NULL;
    
#ifdef _WIN32
    int output_convert_result = MultiByteToWideChar(CP_UTF8, 0, output_path, -1, output_path_wide, MAX_PATH);
    if (output_convert_result == 0) {
        free(file_data);
        return create_error_result("Failed to convert output path to Unicode");
    }
    
    output_file = _wfopen(output_path_wide, L"wb");
#else
    output_file = fopen(output_path, "wb");
#endif

    if (!output_file) {
        free(file_data);
        return create_errno_error("Failed to open output file", errno);
    }

    size_t bytes_written = fwrite(data_to_decrypt, 1, out_len, output_file);
    fclose(output_file);
    free(file_data);

    if (bytes_written != out_len) {
        return create_error_result("Failed to write output file");
    }

    return create_success_result();
}

EXPORT FileOperationResult decrypt_file(
    const char* input_path,
    const char* output_path,
    const char* key_str
) {
    return decrypt_file_ex(input_path, output_path, key_str, CIPHER_AES_256_CFB8);
}

EXPORT FileOperationResult decrypt_buffer_ex(
    unsigned char* data,
    size_t length,
    const char* key_str,
    int cipher_mode
) {
    if (!data || length == 0) {
        return create_success_result();
    }

    unsigned char key[KEY_LEN];
    unsigned char iv[IV_LEN];

    // Check if it's a hex string (64 char)
    if (is_hex_string(key_str, KEY_LEN * 2)) {
        hex_to_bytes(key_str, key, KEY_LEN);
        memcpy(iv, key, IV_LEN);
    } 
    else if (strlen(key_str) >= KEY_LEN) {
        memcpy(key, key_str, KEY_LEN);
        memcpy(iv, key_str, IV_LEN);
    } 
    else {
        return create_error_result("Key must be either 32 characters or 64 hex characters");
    }

    const EVP_CIPHER* cipher = NULL;
    if (cipher_mode == CIPHER_AES_CTR) {
        cipher = EVP_aes_256_ctr();
    } else if (cipher_mode == CIPHER_AES_256_CFB8) {
        cipher = EVP_aes_256_cfb8();
    } else {
        return create_error_result("Unsupported cipher mode");
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return create_error_result("Failed to create cipher context");
    }

    if (1 != EVP_DecryptInit_ex(ctx, cipher, NULL, key, iv)) {
        EVP_CIPHER_CTX_free(ctx);
        return create_error_result("Decryption initialization failed");
    }

    int out_len = 0;
    if (1 != EVP_DecryptUpdate(ctx, data, &out_len, data, (int)length)) {
        EVP_CIPHER_CTX_free(ctx);
        return create_error_result("Decryption failed");
    }

    EVP_CIPHER_CTX_free(ctx);
    return create_success_result();
}

EXPORT FileOperationResult decrypt_buffer(
    unsigned char* data,
    size_t length,
    const char* key_str
) {
    return decrypt_buffer_ex(data, length, key_str, CIPHER_AES_256_CFB8);
}
