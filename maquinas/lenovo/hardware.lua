-- Específico del hardware: ajustes que dependen de touchpad o dispositivos concretos.
-- Si el equipo no tiene touchpad (p. ej. un PC de escritorio), este archivo se puede
-- vaciar o dejar de cargar sin afectar al resto.

-- Gesto de tres dedos en horizontal: cambiar de espacio de trabajo
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
