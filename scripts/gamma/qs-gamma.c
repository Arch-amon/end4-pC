// qs-gamma: per-monitor gamma (dimming) through wlr-gamma-control-unstable-v1.
//
// Quickshell keeps this running and writes commands to its stdin, one per line:
//   set <output-name> <percent>   scale that output's gamma ramp (25..100)
//   quit
// It answers on stdout:
//   ready | ok <name> <percent> | failed <name> | pending <name> | error <text>
//
// A ramp only lasts while this process holds it, so the compositor restores the
// original ramps by itself when the shell (and with it this helper) goes away.

#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-gamma-control-unstable-v1-client-protocol.h"

#define MAX_OUTPUTS 16
#define MAX_WANTED 32

struct output {
    struct wl_output *wl;
    uint32_t global;
    char name[64];
    struct zwlr_gamma_control_v1 *control;
    uint32_t ramp_size;
    int failed;
};

struct wanted {
    char name[64];
    double factor;
};

static struct wl_display *display;
static struct zwlr_gamma_control_manager_v1 *manager;
static struct output outputs[MAX_OUTPUTS];
static struct wanted wanted[MAX_WANTED];
static const struct zwlr_gamma_control_v1_listener control_listener;

static void reply(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void reply(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    putchar('\n');
    fflush(stdout);
}

static struct wanted *find_wanted(const char *name, int create) {
    for (int i = 0; i < MAX_WANTED; i++)
        if (wanted[i].name[0] && strcmp(wanted[i].name, name) == 0) return &wanted[i];
    if (!create) return NULL;
    for (int i = 0; i < MAX_WANTED; i++) {
        if (!wanted[i].name[0]) {
            snprintf(wanted[i].name, sizeof wanted[i].name, "%s", name);
            wanted[i].factor = 1.0;
            return &wanted[i];
        }
    }
    return NULL;
}

static void release_control(struct output *o) {
    if (o->control) zwlr_gamma_control_v1_destroy(o->control);
    o->control = NULL;
    o->ramp_size = 0;
}

static void send_ramp(struct output *o, double factor) {
    const size_t bytes = (size_t)o->ramp_size * 3 * sizeof(uint16_t);
    int fd = memfd_create("qs-gamma-ramp", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, (off_t)bytes) < 0) {
        reply("error memfd %s", strerror(errno));
        if (fd >= 0) close(fd);
        return;
    }
    uint16_t *ramp = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (ramp == MAP_FAILED) {
        reply("error mmap %s", strerror(errno));
        close(fd);
        return;
    }
    const uint32_t n = o->ramp_size;
    for (uint32_t i = 0; i < n; i++) {
        double v = (n > 1 ? (double)i / (n - 1) : 1.0) * factor;
        uint16_t value = (uint16_t)(v * 65535.0 + 0.5);
        ramp[i] = ramp[n + i] = ramp[2 * n + i] = value;
    }
    munmap(ramp, bytes);
    zwlr_gamma_control_v1_set_gamma(o->control, fd);
    close(fd);
}

// Bring one output in line with what was asked for it.
static void apply(struct output *o) {
    if (!o->name[0]) return;
    struct wanted *w = find_wanted(o->name, 0);
    const double factor = w ? w->factor : 1.0;
    if (factor >= 0.999) {
        // Full gamma: give the ramp back instead of holding an identity one.
        if (o->control) release_control(o);
        o->failed = 0;
        reply("ok %s 100", o->name);
        return;
    }
    if (o->failed) {
        reply("failed %s", o->name);
        return;
    }
    if (!o->control) {
        if (!manager) {
            reply("failed %s", o->name);
            return;
        }
        o->control = zwlr_gamma_control_manager_v1_get_gamma_control(manager, o->wl);
        zwlr_gamma_control_v1_add_listener(o->control, &control_listener, o);
        return; // the ramp goes out once gamma_size arrives
    }
    if (!o->ramp_size) return;
    send_ramp(o, factor);
    reply("ok %s %d", o->name, (int)(factor * 100.0 + 0.5));
}

static void control_gamma_size(void *data, struct zwlr_gamma_control_v1 *control, uint32_t size) {
    (void)control;
    struct output *o = data;
    o->ramp_size = size;
    apply(o);
}

static void control_failed(void *data, struct zwlr_gamma_control_v1 *control) {
    (void)control;
    struct output *o = data;
    release_control(o);
    o->failed = 1;
    reply("failed %s", o->name);
}

static const struct zwlr_gamma_control_v1_listener control_listener = {
    .gamma_size = control_gamma_size,
    .failed = control_failed,
};

static void output_geometry(void *d, struct wl_output *w, int32_t x, int32_t y, int32_t pw, int32_t ph,
                            int32_t sp, const char *make, const char *model, int32_t t) {
    (void)d; (void)w; (void)x; (void)y; (void)pw; (void)ph; (void)sp; (void)make; (void)model; (void)t;
}
static void output_mode(void *d, struct wl_output *w, uint32_t f, int32_t wd, int32_t h, int32_t r) {
    (void)d; (void)w; (void)f; (void)wd; (void)h; (void)r;
}
static void output_scale(void *d, struct wl_output *w, int32_t s) { (void)d; (void)w; (void)s; }
static void output_description(void *d, struct wl_output *w, const char *s) { (void)d; (void)w; (void)s; }
static void output_name(void *data, struct wl_output *wl, const char *name) {
    (void)wl;
    struct output *o = data;
    snprintf(o->name, sizeof o->name, "%s", name);
}
static void output_done(void *data, struct wl_output *wl) {
    (void)wl;
    struct output *o = data;
    if (find_wanted(o->name, 0)) apply(o);
}

static const struct wl_output_listener output_listener = {
    .geometry = output_geometry,
    .mode = output_mode,
    .done = output_done,
    .scale = output_scale,
    .name = output_name,
    .description = output_description,
};

static void registry_global(void *data, struct wl_registry *registry, uint32_t id, const char *iface, uint32_t version) {
    (void)data;
    if (strcmp(iface, wl_output_interface.name) == 0) {
        if (version < 4) return; // we need wl_output.name to tell monitors apart
        for (int i = 0; i < MAX_OUTPUTS; i++) {
            if (!outputs[i].wl) {
                memset(&outputs[i], 0, sizeof outputs[i]);
                outputs[i].global = id;
                outputs[i].wl = wl_registry_bind(registry, id, &wl_output_interface, 4);
                wl_output_add_listener(outputs[i].wl, &output_listener, &outputs[i]);
                return;
            }
        }
    } else if (strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
        manager = wl_registry_bind(registry, id, &zwlr_gamma_control_manager_v1_interface, 1);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t id) {
    (void)data; (void)registry;
    for (int i = 0; i < MAX_OUTPUTS; i++) {
        if (outputs[i].wl && outputs[i].global == id) {
            release_control(&outputs[i]);
            wl_output_release(outputs[i].wl);
            memset(&outputs[i], 0, sizeof outputs[i]);
        }
    }
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static void handle_line(char *line) {
    char name[64];
    double percent;
    if (strncmp(line, "quit", 4) == 0) exit(0);
    if (sscanf(line, "set %63s %lf", name, &percent) != 2) {
        reply("error bad command");
        return;
    }
    if (percent < 1) percent = 1;
    if (percent > 100) percent = 100;
    struct wanted *w = find_wanted(name, 1);
    if (!w) {
        reply("error too many outputs");
        return;
    }
    w->factor = percent / 100.0;
    for (int i = 0; i < MAX_OUTPUTS; i++) {
        if (outputs[i].wl && strcmp(outputs[i].name, name) == 0) {
            if (w->factor < 0.999) outputs[i].failed = 0; // allow a retry
            apply(&outputs[i]);
            return;
        }
    }
    reply("pending %s", name);
}

int main(void) {
    display = wl_display_connect(NULL);
    if (!display) {
        reply("error cannot connect to wayland");
        return 1;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    wl_display_roundtrip(display);
    if (!manager) {
        reply("error compositor has no wlr-gamma-control");
        return 1;
    }
    reply("ready");

    char buf[4096];
    size_t used = 0;
    struct pollfd fds[2] = {
        {.fd = wl_display_get_fd(display), .events = POLLIN},
        {.fd = STDIN_FILENO, .events = POLLIN},
    };
    for (;;) {
        wl_display_dispatch_pending(display);
        wl_display_flush(display);
        if (poll(fds, 2, -1) < 0) {
            if (errno == EINTR) continue;
            return 1;
        }
        if (fds[0].revents & (POLLERR | POLLHUP)) return 1;
        if ((fds[0].revents & POLLIN) && wl_display_dispatch(display) < 0) return 1;
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            ssize_t got = read(STDIN_FILENO, buf + used, sizeof buf - used - 1);
            if (got <= 0) return 0; // the shell went away; the ramps go with us
            used += (size_t)got;
            buf[used] = '\0';
            char *start = buf, *nl;
            while ((nl = strchr(start, '\n'))) {
                *nl = '\0';
                handle_line(start);
                start = nl + 1;
            }
            used = strlen(start);
            memmove(buf, start, used);
            if (used >= sizeof buf - 1) used = 0; // garbage line, drop it
        }
    }
}
