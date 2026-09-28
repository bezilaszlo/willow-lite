#include <libinput.h>

struct libinput_device { const char *name; };
struct libinput_event { struct libinput_device *device; };
struct libinput_event_touch { struct libinput_event base; double x; double y; };

struct libinput_event *libinput_event_touch_get_base_event(struct libinput_event_touch *event)
{
    return &event->base;
}

struct libinput_device *libinput_event_get_device(struct libinput_event *event)
{
    return event->device;
}

const char *libinput_device_get_name(struct libinput_device *device)
{
    return device->name;
}

double libinput_event_touch_get_x_transformed(struct libinput_event_touch *event, uint32_t width)
{
    return event->x * width;
}

double libinput_event_touch_get_y_transformed(struct libinput_event_touch *event, uint32_t height)
{
    return event->y * height;
}
