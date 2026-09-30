// sphere.zig — Intersección rayo-esfera
// Usa la fórmula cuadrática para encontrar dónde un rayo
// cruza la superficie de una esfera.

const std = @import("std");
const rl = @import("raylib");
const Intersect = @import("raytracer.zig").Intersect;
const Material = @import("raytracer.zig").Material;

pub const Sphere = struct {
    center: rl.Vector3,
    radius: f32,
    material: Material,

    pub fn intersect(self: Sphere, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        // Fórmula: |origin + t*direction - center|² = radius²
        // Expandido: at² + bt + c = 0, donde a=1 (direction normalizado)
        const center_to_origin = origin.subtract(self.center);

        const b = 2 * direction.dotProduct(center_to_origin);
        const c = center_to_origin.dotProduct(center_to_origin) - self.radius * self.radius;

        const discriminante = b * b - 4.0 * c;
        if (discriminante > 0) {
            // Tomamos la solución más cercana (signo -)
            const solucion = (-b - @sqrt(discriminante)) / 2;
            if (solucion > 0) {
                const point = origin.add(direction.scale(solucion));
                // Normal: dirección del centro al punto de intersección
                const norm = point.subtract(self.center).normalize();

                // UV esférico: mapear la normal a coordenadas [0,1]
                const u = 0.5 + std.math.atan2(norm.z, norm.x) / (2.0 * std.math.pi);
                const v = 0.5 - std.math.asin(@max(-1.0, @min(1.0, norm.y))) / std.math.pi;

                return .{
                    .Material = self.material,
                    .Distancia = solucion,
                    .Normal = norm,
                    .Punto = point,
                    .uv = .{ u, v },
                };
            }
        }
        return null;
    }
};
