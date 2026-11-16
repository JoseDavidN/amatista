#!/bin/sh
# Muestra el greeter. Cuando el usuario inicia sesión, Quickshell se cierra;
# entonces se cierra este Hyprland para que greetd abra la sesión real.
qs -p /etc/greetd/greeter
hyprctl dispatch 'hl.dsp.exit()'
