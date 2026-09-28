#include <libinput.h>
#include <math.h>
#include <stdio.h>

struct libinput_device { const char *name; };
struct libinput_event { struct libinput_device *device; };
struct libinput_event_touch { struct libinput_event base; double x; double y; };

static int check(const char *label, double x, double y, double expected, const char *device_name)
{
    struct libinput_device device = { device_name };
    struct libinput_event_touch event = { { &device }, x, y };
    double actual = libinput_event_touch_get_y_transformed(&event, 1);

    printf("%s: %.4f expected %.4f\n", label, actual, expected);
    return fabs(actual - expected) < 0.012;
}

int main(void)
{
    int ok = 1;

    ok &= check("right-top", 917.0 / 1079.0, 1797.0 / 2339.0,
                195.0 / 1170.0, "NVTCapacitiveTouchScreen");
    ok &= check("right-middle", 942.0 / 1079.0, 1043.0 / 2339.0,
                585.0 / 1170.0, "NVTCapacitiveTouchScreen");
    ok &= check("right-bottom", 927.0 / 1079.0, 252.0 / 2339.0,
                975.0 / 1170.0, "NVTCapacitiveTouchScreen");
    ok &= check("left-top", 118.0 / 540.0, 191.0 / 1170.0,
                191.0 / 1170.0, "NVTCapacitiveTouchScreen");
    ok &= check("center-top", 251.0 / 540.0, 212.0 / 1170.0,
                212.0 / 1170.0, "NVTCapacitiveTouchScreen");
    ok &= check("other-device", 917.0 / 1079.0, 1797.0 / 2339.0,
                1797.0 / 2339.0, "Other touchscreen");
    return ok ? 0 : 1;
}
