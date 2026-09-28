#include <dlfcn.h>

#if defined(WILLOW_TOUCH_MAP_USE_SYSTEM_LIBINPUT)
#include <libinput.h>
#else
typedef unsigned int uint32_t;
struct libinput_event_touch;
struct libinput_event;
struct libinput_device;
struct libinput_event *libinput_event_touch_get_base_event(struct libinput_event_touch *);
struct libinput_device *libinput_event_get_device(struct libinput_event *);
const char *libinput_device_get_name(struct libinput_device *);
double libinput_event_touch_get_x_transformed(struct libinput_event_touch *, uint32_t);
#endif

static int is_willow_touchscreen(struct libinput_event_touch *event)
{
    static const char touchscreen_name[] = "NVTCapacitiveTouchScreen";
    struct libinput_event *base_event;
    struct libinput_device *device;
    const char *name;
    unsigned int i;

    base_event = libinput_event_touch_get_base_event(event);
    if (!base_event)
        return 0;
    device = libinput_event_get_device(base_event);
    if (!device)
        return 0;
    name = libinput_device_get_name(device);
    if (!name)
        return 0;

    for (i = 0; touchscreen_name[i]; i++) {
        if (name[i] != touchscreen_name[i])
            return 0;
    }
    return name[i] == '\0';
}

double libinput_event_touch_get_y_transformed(struct libinput_event_touch *event,
                                               uint32_t height)
{
    static double (*get_original_y)(struct libinput_event_touch *, uint32_t);
    double y;
    double x;

    if (!get_original_y)
        get_original_y = (double (*)(struct libinput_event_touch *, uint32_t))
            dlsym(RTLD_NEXT, "libinput_event_touch_get_y_transformed");
    if (!get_original_y)
        return 0.0;

    y = get_original_y(event, height);
    if (!is_willow_touchscreen(event) || !height)
        return y;

    x = libinput_event_touch_get_x_transformed(event, 1080);
    if (x <= 1080.0 * 0.67)
        return y;

    /* The measured right-column taps map near grid centers after this fold. */
    y = (double)height * 0.94 - y;
    if (y < 0.0)
        return 0.0;
    if (y > height)
        return (double)height;
    return y;
}
