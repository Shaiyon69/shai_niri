#!/bin/sh
# Noctalia post_hook: GTK4 apps read gtk.css only at startup, so reopen LACT's window (not its daemon) if it is open.
# Unapplied LACT edits are lost; applied settings live in the daemon and stay.
pgrep -f '^lact gui' >/dev/null || exit 0
pkill -f '^lact gui'
sleep 0.5
setsid -f lact gui >/dev/null 2>&1
