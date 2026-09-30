// main.zig — Raytracer principal con diorama de cubos texturizados
//
// Este archivo contiene:
// 1. La escena del diorama (materiales, objetos, luces)
// 2. El loop principal con input de cámara
// 3. El renderizado concurrente (multi-threaded)
// 4. La función cast_ray (lanzamiento de rayos con reflexión, refracción, sombras)
//
// Features implementadas:
// - Rotación de cámara orbital (WASD) ........... 10 pts
// - Zoom (Q/E, mouse scroll) .................... 10 pts
// - 5 materiales con textura .................... 25 pts
// - Reflexión ................................... 5 pts
// - Refracción .................................. 10 pts
// - Sombras ..................................... 5 pts
// - Skybox procedural ........................... 20 pts
// - Cubo AABB (forma nueva) .................... 15 pts
// - Concurrencia (threads) ..................... 15 pts
//                                         Total: 115 pts

const std = @import("std");
const rl = @import("raylib");

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Forma = @import("formas.zig").Forma;
const Camera = @import("camera.zig").Camera;
const rt = @import("raytracer.zig");
const tex = @import("texture.zig");
const htmlColor = @import("cute_colors.zig").htmlColor;

// ============================================================
// Configuración
// ============================================================

const width = 800;
const height = 600;
const num_threads: usize = 8; // Número de threads para renderizado concurrente
const max_recursion: usize = 3; // Profundidad máxima de reflexión/refracción

// ============================================================
// Contexto de renderizado (se pasa a cada thread)
// ============================================================

const RenderContext = struct {
    pixels: [*]rl.Color,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    objects: []const Forma,
    lights: []const rt.Light,
    camera: Camera,
    textures: []const tex.Texture,
    aspect_ratio: f32,
    fov_scale: f32,
};

// ============================================================
// Main
// ============================================================

pub fn main() !void {
    // Allocator simple para las texturas (no necesita cleanup manual)
    const alloc = std.heap.page_allocator;

    // Inicializar ventana
    rl.initWindow(width, height, "Raytracing Diorama");
    rl.setTraceLogLevel(.warning);
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var framebuffer = Framebuffer.init(width, height);

    // ----------------------------------------------------------
    // Texturas procedurales (una por material)
    // ----------------------------------------------------------
    const textures = [_]tex.Texture{
        // 0: Piedra — checkerboard gris (piso)
        try tex.createCheckerboard(alloc, 32, 4, htmlColor("#a09080"), htmlColor("#807060")),
        // 1: Ladrillo — patrón de ladrillos (paredes)
        try tex.createBricks(alloc, 32, htmlColor("#b05a3c"), htmlColor("#c8b8a0")),
        // 2: Madera — franjas horizontales (caja)
        try tex.createStripes(alloc, 32, 4, htmlColor("#b08040"), htmlColor("#785828")),
        // 3: Metal — sólido plateado (cubo reflectivo)
        try tex.createSolid(alloc, 32, htmlColor("#d0d0d0")),
        // 4: Cristal — checkerboard sutil azul-hielo (cubo transparente)
        try tex.createCheckerboard(alloc, 32, 16, htmlColor("#d0e8f0"), htmlColor("#b8d8e8")),
    };

    // ----------------------------------------------------------
    // 5 Materiales (cada uno con textura y parámetros únicos)
    // ----------------------------------------------------------

    // 1. Piedra: difuso, poco brillo
    const stone = rt.Material{
        .Color = rt.V3FromColor(htmlColor("#908070")),
        .Especular = 10,
        .Refractive_index = 0,
        .Propiedades = .{ .Albedo = 0.8, .Especular = 0.1, .Reflectividad = 0, .Transparencia = 0 },
        .texture_index = 0,
    };
    // 2. Ladrillo: difuso, muy poco brillo
    const brick = rt.Material{
        .Color = rt.V3FromColor(htmlColor("#b05a3c")),
        .Especular = 5,
        .Refractive_index = 0,
        .Propiedades = .{ .Albedo = 0.9, .Especular = 0.05, .Reflectividad = 0, .Transparencia = 0 },
        .texture_index = 1,
    };
    // 3. Madera: difuso con poco especular
    const wood = rt.Material{
        .Color = rt.V3FromColor(htmlColor("#b08040")),
        .Especular = 8,
        .Refractive_index = 0,
        .Propiedades = .{ .Albedo = 0.8, .Especular = 0.1, .Reflectividad = 0, .Transparencia = 0 },
        .texture_index = 2,
    };
    // 4. Metal: muy reflectivo, brillo concentrado
    const metal = rt.Material{
        .Color = rt.V3FromColor(htmlColor("#c0c0c0")),
        .Especular = 100,
        .Refractive_index = 0,
        .Propiedades = .{ .Albedo = 0.1, .Especular = 0.8, .Reflectividad = 0.7, .Transparencia = 0 },
        .texture_index = 3,
    };
    // 5. Cristal: transparente con refracción (vidrio)
    const crystal = rt.Material{
        .Color = rt.V3FromColor(htmlColor("#b0c4de")),
        .Especular = 125,
        .Refractive_index = 1.5,
        .Propiedades = .{ .Albedo = 0, .Especular = 0.5, .Reflectividad = 0.1, .Transparencia = 0.8 },
        .texture_index = 4,
    };

    // ----------------------------------------------------------
    // Objetos de la escena (diorama)
    // ----------------------------------------------------------
    const objects = [_]Forma{
        // Piso grande (piedra)
        .{ .Cube = .{
            .min = .{ .x = -10, .y = -0.5, .z = -15 },
            .max = .{ .x = 10, .y = 0, .z = 5 },
            .material = stone,
        } },
        // Pared trasera (ladrillo)
        .{ .Cube = .{
            .min = .{ .x = -10, .y = 0, .z = -15 },
            .max = .{ .x = 10, .y = 8, .z = -14 },
            .material = brick,
        } },
        // Pared izquierda (ladrillo)
        .{ .Cube = .{
            .min = .{ .x = -10, .y = 0, .z = -15 },
            .max = .{ .x = -9, .y = 8, .z = 5 },
            .material = brick,
        } },
        // Caja de madera
        .{ .Cube = .{
            .min = .{ .x = 3, .y = 0, .z = -6 },
            .max = .{ .x = 5.5, .y = 2.5, .z = -3.5 },
            .material = wood,
        } },
        // Cubo metálico (reflectivo)
        .{ .Cube = .{
            .min = .{ .x = -5.5, .y = 0, .z = -4 },
            .max = .{ .x = -3, .y = 2.5, .z = -1.5 },
            .material = metal,
        } },
        // Cubo de cristal (transparente)
        .{ .Cube = .{
            .min = .{ .x = -1, .y = 0, .z = -9 },
            .max = .{ .x = 1.5, .y = 2, .z = -6.5 },
            .material = crystal,
        } },
        // Esfera espejo (demuestra la esfera del código base + reflexión)
        .{ .Sphere = .{
            .center = .{ .x = 0, .y = 2, .z = -2 },
            .radius = 2,
            .material = metal,
        } },
    };

    // ----------------------------------------------------------
    // Luces
    // ----------------------------------------------------------
    const lights = [_]rt.Light{
        // Luz cálida principal (arriba-derecha-frente)
        .{
            .Color = rt.V3FromColor(htmlColor("#fff5e0")),
            .Position = .{ .x = 8, .y = 15, .z = 5 },
            .Intensity = 1.0,
        },
        // Luz fría de relleno (arriba-izquierda)
        .{
            .Color = rt.V3FromColor(htmlColor("#e0e8ff")),
            .Position = .{ .x = -10, .y = 12, .z = -5 },
            .Intensity = 0.6,
        },
    };

    // ----------------------------------------------------------
    // Cámara orbital
    // ----------------------------------------------------------
    const look_target = rl.Vector3{ .x = 0, .y = 2, .z = -5 };
    var camera_distance: f32 = 25;
    var camera_x_angle: f32 = 0.8; // ~45° desde el frente-derecha
    var camera_y_angle: f32 = 0.3; // Ligeramente elevada

    const camera_turn_speed: f32 = std.math.pi / 2.0;
    const zoom_speed: f32 = 15;

    var camera: Camera = .init(.{ .x = 0, .y = 5, .z = camera_distance }, look_target);

    // ----------------------------------------------------------
    // Loop principal
    // ----------------------------------------------------------
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // --- Input: Rotación (WASD) ---
        if (rl.isKeyDown(.a)) camera_x_angle += camera_turn_speed * dt;
        if (rl.isKeyDown(.d)) camera_x_angle -= camera_turn_speed * dt;
        if (rl.isKeyDown(.w)) {
            camera_y_angle += camera_turn_speed * dt;
            camera_y_angle = @min(std.math.pi / 3.0, camera_y_angle);
        }
        if (rl.isKeyDown(.s)) {
            camera_y_angle -= camera_turn_speed * dt;
            camera_y_angle = @max(-std.math.pi / 8.0, camera_y_angle);
        }

        // --- Input: Zoom (Q/E y mouse scroll) ---
        const scroll = rl.getMouseWheelMove();
        if (scroll != 0) {
            camera_distance -= scroll * zoom_speed * 0.3;
        }
        if (rl.isKeyDown(.q)) camera_distance -= zoom_speed * dt;
        if (rl.isKeyDown(.e)) camera_distance += zoom_speed * dt;
        camera_distance = @max(10, @min(50, camera_distance));

        // --- Actualizar posición de cámara (órbita) ---
        camera.Postition.x = look_target.x + @cos(camera_x_angle) * camera_distance * @cos(camera_y_angle);
        camera.Postition.y = look_target.y + @sin(camera_y_angle) * camera_distance;
        camera.Postition.z = look_target.z + @sin(camera_x_angle) * camera_distance * @cos(camera_y_angle);
        camera.lookAt(look_target);

        // --- Renderizar ---
        framebuffer.clear();
        render(&framebuffer, &objects, &lights, camera, &textures);

        // --- Mostrar en pantalla ---
        try framebuffer.swapBuffers();
    }
}

// ============================================================
// Renderizado concurrente
// ============================================================

/// Divide la imagen en bandas horizontales y asigna una a cada thread
fn render(
    fb: *Framebuffer,
    objects: []const Forma,
    lights: []const rt.Light,
    camera: Camera,
    textures: []const tex.Texture,
) void {
    const pixels = fb.getPixels();
    const w = fb.width;
    const h = fb.height;
    const aspect_ratio: f32 = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
    const fov_scale = @tan(std.math.pi / 6.0); // FOV = 60°

    const band_height = h / num_threads;
    var threads: [num_threads]std.Thread = undefined;

    for (0..num_threads) |i| {
        const start_y = i * band_height;
        const end_y = if (i == num_threads - 1) h else (i + 1) * band_height;

        threads[i] = std.Thread.spawn(.{}, renderBand, .{RenderContext{
            .pixels = pixels,
            .w = w,
            .h = h,
            .start_y = start_y,
            .end_y = end_y,
            .objects = objects,
            .lights = lights,
            .camera = camera,
            .textures = textures,
            .aspect_ratio = aspect_ratio,
            .fov_scale = fov_scale,
        }}) catch unreachable;
    }

    // Esperar a que todos los threads terminen
    for (threads) |t| t.join();
}

/// Cada thread renderiza su banda de filas
fn renderBand(ctx: RenderContext) void {
    const w_f32: f32 = @floatFromInt(ctx.w);
    const h_f32: f32 = @floatFromInt(ctx.h);

    for (ctx.start_y..ctx.end_y) |screen_y| {
        for (0..ctx.w) |screen_x| {
            const x_f32: f32 = @floatFromInt(screen_x);
            const y_f32: f32 = @floatFromInt(screen_y);

            // Normalizar coordenadas de pantalla a [-1, 1]
            const ndc_x = (x_f32 * 2) / w_f32 - 1;
            const ndc_y = 1 - (y_f32 * 2) / h_f32;

            // Dirección del rayo en espacio de cámara
            const dir_local = (rl.Vector3{
                .x = ndc_x * ctx.aspect_ratio * ctx.fov_scale,
                .y = ndc_y * ctx.fov_scale,
                .z = 1,
            }).normalize();

            // Transformar a espacio del mundo usando los vectores de la cámara
            const direction = rl.Vector3{
                .x = dir_local.x * ctx.camera.Right.x + dir_local.y * ctx.camera.Up.x + dir_local.z * ctx.camera.Forward.x,
                .y = dir_local.x * ctx.camera.Right.y + dir_local.y * ctx.camera.Up.y + dir_local.z * ctx.camera.Forward.y,
                .z = dir_local.x * ctx.camera.Right.z + dir_local.y * ctx.camera.Up.z + dir_local.z * ctx.camera.Forward.z,
            };

            // Lanzar rayo y obtener color
            const color = cast_ray(ctx.camera.Postition, direction, ctx.objects, ctx.lights, ctx.textures, max_recursion);

            // Escribir píxel directamente al buffer
            ctx.pixels[screen_y * ctx.w + screen_x] = rt.V3ToColor(color);
        }
    }
}

// ============================================================
// Lanzamiento de rayos (cast_ray)
// ============================================================

/// Lanza un rayo desde `origin` en `direction` y calcula el color del píxel.
/// Implementa reflexión, refracción, sombras, texturas y skybox.
fn cast_ray(
    origin: rl.Vector3,
    direction: rl.Vector3,
    objects: []const Forma,
    lights: []const rt.Light,
    textures: []const tex.Texture,
    depth: usize,
) rl.Vector3 {
    // ---- Encontrar la intersección más cercana ----
    var closest_hit: ?rt.Intersect = null;
    var z_buffer: f32 = std.math.floatMax(f32);

    for (objects) |object| {
        const hit = object.intersect(origin, direction) orelse continue;
        if (hit.Distancia < z_buffer) {
            z_buffer = hit.Distancia;
            closest_hit = hit;
        }
    }

    // Si no golpeamos nada, devolver el color del skybox
    const hit = closest_hit orelse return tex.sampleSkybox(direction);

    const mat = hit.Material;
    var color: rl.Vector3 = .zero();

    // ---- Color base: de la textura o del material ----
    var base_color = mat.Color;
    if (mat.texture_index) |tex_idx| {
        if (tex_idx < textures.len) {
            base_color = textures[tex_idx].sample(hit.uv[0], hit.uv[1]);
        }
    }

    // ---- Luz ambiental mínima (evita negro total en sombras) ----
    color = color.add(base_color.scale(0.05));

    // ---- Reflexión ----
    if (mat.Propiedades.Reflectividad > 0 and depth > 0) {
        const reflect_dir = rl.Vector3.reflect(direction, hit.Normal);
        // Offset pequeño para evitar auto-intersección
        const new_origin = hit.Punto.add(reflect_dir.scale(0.001));
        const reflect_color = cast_ray(new_origin, reflect_dir, objects, lights, textures, depth - 1);
        color = color.add(reflect_color.scale(mat.Propiedades.Reflectividad));
    }

    // ---- Refracción (transparencia) ----
    if (mat.Propiedades.Transparencia > 0 and depth > 0) {
        if (refract(direction, hit.Normal, mat.Refractive_index)) |refract_dir| {
            // Offset en la dirección original para pasar "a través" de la superficie
            const new_origin = hit.Punto.add(direction.scale(0.001));
            const refract_color = cast_ray(new_origin, refract_dir, objects, lights, textures, depth - 1);
            color = color.add(refract_color.scale(mat.Propiedades.Transparencia));
        } else {
            // Reflexión total interna (ángulo demasiado rasante)
            if (depth > 0) {
                const reflect_dir = rl.Vector3.reflect(direction, hit.Normal);
                const new_origin = hit.Punto.add(reflect_dir.scale(0.001));
                const reflect_color = cast_ray(new_origin, reflect_dir, objects, lights, textures, depth - 1);
                color = color.add(reflect_color.scale(mat.Propiedades.Transparencia));
            }
        }
    }

    // ---- Iluminación difusa y especular (por cada luz) ----
    const view_dir = direction.scale(-1); // Dirección del punto hacia la cámara

    for (lights) |light| {
        // Verificar si el punto está en sombra respecto a esta luz
        if (obscured(hit.Punto, light, objects)) continue;

        // Dirección del punto hacia la luz
        const light_dir = light.Position.subtract(hit.Punto).normalize();

        // DIFUSO: intensidad depende del ángulo entre la normal y la dirección de la luz
        // (dot product positivo = la luz ilumina la superficie)
        const diff_intensity = @max(0.0, hit.Normal.dotProduct(light_dir)) * light.Intensity;
        const diffuse = base_color.scale(diff_intensity);

        // ESPECULAR: reflejo brillante de la fuente de luz
        // Calculamos la dirección reflejada de la luz y la comparamos con la vista
        const reflect_light_dir = rl.Vector3.reflect(light_dir.scale(-1), hit.Normal);
        const spec_alignment = @max(0.0, reflect_light_dir.dotProduct(view_dir));
        const spec_intensity = std.math.pow(f32, spec_alignment, mat.Especular) * light.Intensity;
        const specular = light.Color.scale(spec_intensity);

        // Mezclar componentes según las propiedades del material
        color = color.add(diffuse.scale(mat.Propiedades.Albedo));
        color = color.add(specular.scale(mat.Propiedades.Especular));
    }

    return color;
}

// ============================================================
// Refracción (Ley de Snell)
// ============================================================

/// Calcula la dirección refractada usando la Ley de Snell.
/// Retorna null si hay reflexión total interna.
fn refract(incident: rl.Vector3, normal: rl.Vector3, refractive_index: f32) ?rl.Vector3 {
    var cosi = incident.dotProduct(normal);

    var etai: f32 = 1; // Índice del medio exterior (aire = 1)
    var etat = refractive_index; // Índice del material
    var n = normal;

    if (cosi > 0) {
        // El rayo sale del objeto → intercambiar índices y flipear normal
        std.mem.swap(f32, &etai, &etat);
        n = n.scale(-1);
    } else {
        cosi = -cosi;
    }

    const eta = etai / etat;
    const k = 1 - eta * eta * (1 - cosi * cosi);

    if (k < 0) {
        // Reflexión total interna (sin refracción posible)
        return null;
    } else {
        return (incident.scale(eta).add(n.scale(eta * cosi - @sqrt(k)))).normalize();
    }
}

// ============================================================
// Sombras
// ============================================================

/// Verifica si un punto está en sombra respecto a una luz.
/// Lanza un rayo desde el punto hacia la luz y revisa si algo lo bloquea.
fn obscured(origin: rl.Vector3, light: rt.Light, objects: []const Forma) bool {
    const light_vec = light.Position.subtract(origin);
    const light_dir = light_vec.normalize();

    // Distancia al punto de luz
    const light_dist = @sqrt(light_vec.x * light_vec.x + light_vec.y * light_vec.y + light_vec.z * light_vec.z);

    // Offset para evitar auto-intersección (shadow acne)
    const shadow_origin = origin.add(light_dir.scale(0.01));

    for (objects) |object| {
        const hit_result = object.intersect(shadow_origin, light_dir) orelse continue;
        // Si el objeto está entre el punto y la luz, hay sombra
        // (excepto objetos muy transparentes como el cristal)
        if (hit_result.Distancia < light_dist and hit_result.Material.Propiedades.Transparencia < 0.5) {
            return true;
        }
    }
    return false;
}
