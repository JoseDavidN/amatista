-- Teclado, mouse y touchpad. Es igual para todos los equipos: los ajustes de
-- touchpad y el gesto solo se usan si el equipo tiene touchpad.
hl.config({
    input = {
        kb_layout       = "latam",
        follow_mouse    = 1,
        sensitivity     = 0,

        touchpad = {
            natural_scroll       = true,  -- desplazamiento como en el celular
            tap_to_click         = true,  -- tocar = clic
            disable_while_typing = true,
        },
    },
})

-- Gesto de tres dedos en horizontal: cambiar de espacio de trabajo
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
