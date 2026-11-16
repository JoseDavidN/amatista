-- Cursor Amatista (lila con borde oscuro), instalado en /usr/share/icons/Amatista
hl.env("XCURSOR_THEME", "Amatista")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
-- hl.env("QT_WAYLAND_DISABLE_WINDOW_DECORATION", "1")
-- hl.env("GDK_SCALE", "1")

-- Widevine (Netflix, Spotify web, etc.) para navegadores Qt WebEngine como Mitis.
-- La librería la instala el paquete AUR chromium-widevine.
hl.env("QTWEBENGINE_CHROMIUM_FLAGS", "--widevine-path=/usr/lib/chromium/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so")

-- Agente SSH de gcr (gcr-ssh-agent.socket): las claves SSH usan el llavero.
-- Hyprland arranca desde greetd y no recibe el SSH_AUTH_SOCK de systemd.
local runtime = os.getenv("XDG_RUNTIME_DIR")
if runtime then
    hl.env("SSH_AUTH_SOCK", runtime .. "/gcr/ssh")
end
