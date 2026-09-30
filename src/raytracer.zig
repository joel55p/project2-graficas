// raytracer.zig — Tipos centrales del raytracer
// Material define las propiedades ópticas de una superficie.
// Intersect contiene la información de un rayo que golpea una superficie.
// Light define una fuente de luz puntual.

const rl = @import("raylib");

/// Convierte un color RGBA (u8) a un Vector3 normalizado [0,1]
pub fn V3FromColor(src: rl.Color) rl.Vector3 {
    const x: f32 = @floatFromInt(src.r);
    const y: f32 = @floatFromInt(src.g);
    const z: f32 = @floatFromInt(src.b);
    return .{ .x = x / 255, .y = y / 255, .z = z / 255 };
}

/// Convierte un Vector3 [0,1] de vuelta a color RGBA (u8)
pub fn V3ToColor(color: rl.Vector3) rl.Color {
    const r: u8 = @intFromFloat(@max(0, @min(255, color.x * 255)));
    const g: u8 = @intFromFloat(@max(0, @min(255, color.y * 255)));
    const b: u8 = @intFromFloat(@max(0, @min(255, color.z * 255)));
    return .{ .r = r, .g = g, .b = b, .a = 0xff };
}

/// Luz puntual con posición, color e intensidad
pub const Light = struct {
    Color: rl.Vector3,
    Position: rl.Vector3,
    Intensity: f32,
};

/// Material define las propiedades ópticas de una superficie
pub const Material = struct {
    // Color base (RGB como Vector3 normalizado)
    Color: rl.Vector3,
    // Exponente especular (qué tan concentrado es el brillo)
    Especular: f32,
    // Índice de refracción (vidrio ≈ 1.5, diamante ≈ 2.42)
    Refractive_index: f32,
    // Proporciones de cada componente de iluminación (deben sumar ~1)
    Propiedades: struct {
        Albedo: f32, // Difuso
        Especular: f32, // Brillo especular
        Reflectividad: f32, // Reflexión tipo espejo
        Transparencia: f32, // Refracción/transparencia
    },
    // Índice a la textura procedural (null = usa Color plano)
    texture_index: ?usize = null,
};

/// Resultado de la intersección de un rayo con una superficie
pub const Intersect = struct {
    Material: Material,
    Distancia: f32,
    Normal: rl.Vector3,
    Punto: rl.Vector3,
    // Coordenadas UV para texturas [0,1]
    uv: [2]f32 = .{ 0, 0 },
};
