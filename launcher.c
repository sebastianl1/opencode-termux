/*
 * OpenCode — Termux launcher
 *
 * Ejecuta el binario glibc de OpenCode (opencode.real) dentro de la capa
 * glibc de Termux invocando el cargador dinamico glibc directamente:
 *
 *   ld-linux-aarch64.so.1 --library-path <glibc/lib> opencode.real [args]
 *
 * PREFIX se inyecta en tiempo de compilacion:
 *   cc -O2 -DPREFIX="\"$PREFIX\"" -o opencode launcher.c
 */

#ifndef PREFIX
#define PREFIX "/data/data/com.termux/files/usr"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define GLIBC_LOADER PREFIX "/glibc/lib/ld-linux-aarch64.so.1"
#define GLIBC_LIB    PREFIX "/glibc/lib"
#define GLIBC_RUNTIME PREFIX "/share/opencode/glibc-runtime"
#define OPENCODE_REAL PREFIX "/share/opencode/opencode.real"
#define SSL_CERTS    PREFIX "/etc/tls/cert.pem"
#define LIBRARY_PATH GLIBC_RUNTIME ":" GLIBC_LIB

int main(int argc, char **argv) {
    char **args;
    int i;

    /*
     * Limpia LD_PRELOAD/LD_LIBRARY_PATH de bionic: si Termux inyecta la
     * libreria 'libtermux-exec-ld-preload.so' (libc de Android), el cargador
     * glibc no puede cargarla (version 'GLIBC' not found) y opencode falla.
     */
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");

    setenv("SSL_CERT_FILE", SSL_CERTS, 1);

    args = calloc((size_t)argc + 4, sizeof(char *));
    if (!args) {
        perror("opencode: calloc");
        return 127;
    }

    args[0] = GLIBC_LOADER;
    args[1] = "--library-path";
    args[2] = LIBRARY_PATH;
    args[3] = OPENCODE_REAL;
    for (i = 1; i < argc; i++) {
        args[i + 3] = argv[i];
    }
    args[argc + 3] = NULL;

    execv(GLIBC_LOADER, args);
    perror("opencode");
    return 127;
}
