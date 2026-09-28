if [ "$(tty 2>/dev/null)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    if [ -r /usr/local/lib/willow-touch-map.so ]; then
        exec /lib/ld-linux-aarch64.so.1 --preload /usr/local/lib/willow-touch-map.so /usr/bin/sway
    fi
    exec dbus-run-session sway
fi
