// texture.zig — Texturas procedurales y skybox
// Las texturas se generan en memoria como arreglos de píxeles.
// Cada material tiene su propia textura con un patrón visual diferente.
// El skybox es un gradiente procedural que reemplaza el fondo negro.

const std = @import("std");
const rl = @import("raylib");

/// Textura: un arreglo 2D de píxeles que se muestrea con coordenadas UV
pub const Texture = struct {
    width: usize,
    height: usize,
    pixels: []rl.Color,

    /// Muestrea la textura en coordenadas UV [0,1].
    /// Las coordenadas se repiten (wrap) si salen del rango.
    pub fn sample(self: Texture, u_raw: f32, v_raw: f32) rl.Vector3 {
        // Wrap UV a [0, 1)
        var u = u_raw - @floor(u_raw);
        var v = v_raw - @floor(v_raw);
        if (u < 0) u += 1;
        if (v < 0) v += 1;

        const w_f: f32 = @floatFromInt(self.width);
        const h_f: f32 = @floatFromInt(self.height);
        const x: usize = @intFromFloat(@min(w_f - 1, u * w_f));
        const y: usize = @intFromFloat(@min(h_f - 1, v * h_f));

        const pixel = self.pixels[y * self.width + x];
        const r: f32 = @floatFromInt(pixel.r);
        const g: f32 = @floatFromInt(pixel.g);
        const b: f32 = @floatFromInt(pixel.b);
        return .{ .x = r / 255.0, .y = g / 255.0, .z = b / 255.0 };
    }
};

// ============================================================
// Skybox procedural
// ============================================================

/// Devuelve el color del cielo para un rayo que no golpeó ningún objeto.
/// Usa la dirección Y para interpolar entre cielo, horizonte y suelo.
pub fn sampleSkybox(direction: rl.Vector3) rl.Vector3 {
    // Mapear direction.y de [-1, 1] a [0, 1]
    const t = 0.5 * (direction.y + 1.0);

    // Colores del cielo
    const sky = rl.Vector3{ .x = 0.35, .y = 0.55, .z = 0.92 }; // Azul cielo
    const horizon = rl.Vector3{ .x = 0.88, .y = 0.88, .z = 0.90 }; // Blanco-gris
    const ground = rl.Vector3{ .x = 0.35, .y = 0.30, .z = 0.25 }; // Café tierra

    if (t > 0.5) {
        // Arriba del horizonte: de blanco a azul
        const s = (t - 0.5) * 2.0;
        return lerp3(horizon, sky, s);
    } else {
        // Abajo del horizonte: de café a blanco
        const s = t * 2.0;
        return lerp3(ground, horizon, s);
    }
}

/// Interpolación lineal entre dos vectores
fn lerp3(a: rl.Vector3, b: rl.Vector3, t: f32) rl.Vector3 {
    return .{
        .x = a.x + (b.x - a.x) * t,
        .y = a.y + (b.y - a.y) * t,
        .z = a.z + (b.z - a.z) * t,
    };
}

// ============================================================
// Generadores de texturas procedurales
// ============================================================

/// Crea un patrón de tablero de ajedrez (checkerboard)
pub fn createCheckerboard(alloc: std.mem.Allocator, size: usize, cell: usize, c1: rl.Color, c2: rl.Color) !Texture {
    const pixels = try alloc.alloc(rl.Color, size * size);
    for (0..size) |y| {
        for (0..size) |x| {
            const checker = ((x / cell) + (y / cell)) % 2 == 0;
            pixels[y * size + x] = if (checker) c1 else c2;
        }
    }
    return .{ .width = size, .height = size, .pixels = pixels };
}

/// Crea un patrón de franjas horizontales (para madera)
pub fn createStripes(alloc: std.mem.Allocator, size: usize, stripe_h: usize, c1: rl.Color, c2: rl.Color) !Texture {
    const pixels = try alloc.alloc(rl.Color, size * size);
    for (0..size) |y| {
        for (0..size) |x| {
            const stripe = (y / stripe_h) % 2 == 0;
            pixels[y * size + x] = if (stripe) c1 else c2;
        }
    }
    return .{ .width = size, .height = size, .pixels = pixels };
}

/// Crea una textura de un solo color (para metal, cristal)
pub fn createSolid(alloc: std.mem.Allocator, size: usize, color: rl.Color) !Texture {
    const pixels = try alloc.alloc(rl.Color, size * size);
    @memset(pixels, color);
    return .{ .width = size, .height = size, .pixels = pixels };
}

/// Crea un patrón de ladrillos (rectángulos offset)
pub fn createBricks(alloc: std.mem.Allocator, size: usize, c_brick: rl.Color, c_mortar: rl.Color) !Texture {
    const pixels = try alloc.alloc(rl.Color, size * size);
    const brick_h: usize = size / 4; // 4 filas de ladrillos
    const brick_w: usize = size / 4; // 4 ladrillos por fila
    const mortar: usize = 1; // grosor de la junta

    for (0..size) |y| {
        for (0..size) |x| {
            const row = y / brick_h;
            // Offset: filas pares e impares se desplazan medio ladrillo
            const offset_x = if (row % 2 == 0) x else x + brick_w / 2;
            // Junta horizontal (entre filas)
            const is_h_mortar = (y % brick_h) < mortar;
            // Junta vertical (entre ladrillos)
            const is_v_mortar = (offset_x % brick_w) < mortar;

            pixels[y * size + x] = if (is_h_mortar or is_v_mortar) c_mortar else c_brick;
        }
    }
    return .{ .width = size, .height = size, .pixels = pixels };
}
