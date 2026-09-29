#!/usr/bin/python
"""Show the phone preview at its original aspect ratio in a tiled window."""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkVnc", "2.0")

from gi.repository import Gtk, GtkVnc


window = Gtk.Window(title="Willow Lite Preview")
window.set_default_size(400, 700)
window.connect("destroy", Gtk.main_quit)

style = Gtk.CssProvider()
style.load_from_data(b"window { background-color: #111620; }")
window.get_style_context().add_provider(style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

frame = Gtk.AspectFrame.new(None, 0.5, 0.5, 540 / 1170, False)
frame.set_shadow_type(Gtk.ShadowType.NONE)
window.add(frame)

display = GtkVnc.Display()
display.set_scaling(True)
display.set_force_size(False)
display.connect("vnc-disconnected", lambda *_: Gtk.main_quit())
frame.add(display)

window.show_all()
display.open_host("127.0.0.1", "5909")
Gtk.main()
