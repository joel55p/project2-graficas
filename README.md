# Raytracing Diorama

Diorama de cubos texturizados con raytracing implementado en Zig usando Raylib.

## Features

- Rotación de cámara (WASD)
- Zoom (Q/E o scroll del mouse)
- 5 materiales con textura (piedra, ladrillo, madera, metal, cristal)
- Reflexión
- Refracción
- Sombras
- Skybox procedural
- Cubos (AABB) como forma nueva
- Renderizado concurrente (multi-threaded)

## Controles

| Tecla | Acción |
|-------|--------|
| W/S | Rotar cámara arriba/abajo |
| A/D | Rotar cámara izquierda/derecha |
| Q/E | Acercar/alejar cámara |
| Scroll | Acercar/alejar cámara |

## Build

```bash
zig build run -Doptimize=ReleaseFast
zig build run
```


## Video

<!--  -->
