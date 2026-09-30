// cube.zig — Intersección rayo-cubo (AABB) usando el Slab Method
//
// Un AABB (Axis-Aligned Bounding Box) es una caja alineada a los ejes.
// Se define por dos esquinas: min y max.
//
// El Slab Method funciona así:
// Para cada eje (X, Y, Z), calculamos dónde el rayo entra y sale
// del "slab" (la franja entre las dos caras de ese eje).
// Si las franjas de los 3 ejes se superponen, el rayo golpea la caja.
//
// Esta es la "forma no vista en clase" (15 pts).

const std = @import("std");
const rl = @import("raylib");
const Material = @import("raytracer.zig").Material;
const Intersect = @import("raytracer.zig").Intersect;

pub const Cube = struct {
    min: rl.Vector3, // Esquina mínima (x_min, y_min, z_min)
    max: rl.Vector3, // Esquina máxima (x_max, y_max, z_max)
    material: Material,

    pub fn intersect(self: Cube, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        // Convertir vectores a arreglos para iterar por eje
        const o = [3]f32{ origin.x, origin.y, origin.z };
        const d = [3]f32{ direction.x, direction.y, direction.z };
        const bmin = [3]f32{ self.min.x, self.min.y, self.min.z };
        const bmax = [3]f32{ self.max.x, self.max.y, self.max.z };

        var tmin_val: f32 = -std.math.floatMax(f32);
        var tmax_val: f32 = std.math.floatMax(f32);

        // Tracking: qué cara fue golpeada (para calcular la normal)
        var tmin_axis: usize = 0;
        var tmin_sign: f32 = -1;
        var tmax_axis: usize = 0;
        var tmax_sign: f32 = 1;

        // Para cada eje: ¿dónde entra y sale el rayo del slab?
        for (0..3) |i| {
            if (@abs(d[i]) < 1e-8) {
                // Rayo paralelo a este par de caras
                // Si el origen está fuera del slab, no hay intersección
                if (o[i] < bmin[i] or o[i] > bmax[i]) return null;
            } else {
                // t1: distancia a la cara cercana, t2: distancia a la cara lejana
                var t1 = (bmin[i] - o[i]) / d[i];
                var t2 = (bmax[i] - o[i]) / d[i];
                var sign: f32 = -1;

                // Asegurar que t1 < t2 (intercambiar si el rayo va en dirección negativa)
                if (t1 > t2) {
                    std.mem.swap(f32, &t1, &t2);
                    sign = 1;
                }

                // Actualizar el rango de intersección
                if (t1 > tmin_val) {
                    tmin_val = t1;
                    tmin_axis = i; // Este eje define la cara de entrada
                    tmin_sign = sign;
                }
                if (t2 < tmax_val) {
                    tmax_val = t2;
                    tmax_axis = i; // Este eje define la cara de salida
                    tmax_sign = -sign; // Normal opuesta a la de entrada
                }

                // Si los rangos no se superponen, no hay intersección
                if (tmin_val > tmax_val) return null;
            }
        }

        // Determinar si golpeamos desde afuera (tmin > 0) o desde adentro (usar tmax)
        const front_hit = tmin_val > 0;
        const t = if (front_hit) tmin_val else tmax_val;
        if (t < 0) return null; // La caja está detrás del rayo

        const n_axis = if (front_hit) tmin_axis else tmax_axis;
        const n_sign = if (front_hit) tmin_sign else tmax_sign;

        const point = origin.add(direction.scale(t));

        // Normal: un vector unitario perpendicular a la cara golpeada
        var normal = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
        switch (n_axis) {
            0 => normal.x = n_sign, // Cara X
            1 => normal.y = n_sign, // Cara Y
            2 => normal.z = n_sign, // Cara Z
            else => {},
        }

        // Coordenadas UV para la textura de la cara golpeada
        const uv = computeUV(self.min, self.max, point, n_axis);

        return .{
            .Material = self.material,
            .Distancia = t,
            .Normal = normal,
            .Punto = point,
            .uv = uv,
        };
    }

    /// Calcula coordenadas UV [0,1] proyectando el punto en la cara golpeada
    fn computeUV(bmin: rl.Vector3, bmax: rl.Vector3, point: rl.Vector3, axis: usize) [2]f32 {
        const min_a = [3]f32{ bmin.x, bmin.y, bmin.z };
        const max_a = [3]f32{ bmax.x, bmax.y, bmax.z };
        const p = [3]f32{ point.x, point.y, point.z };

        // Según la cara golpeada, proyectar en los otros dos ejes
        // Cara X → usar Z y Y
        // Cara Y → usar X y Z
        // Cara Z → usar X y Y
        const u_axis: usize = if (axis == 0) 2 else 0;
        const v_axis: usize = if (axis == 2) 1 else if (axis == 0) 1 else 2;

        const size_u = max_a[u_axis] - min_a[u_axis];
        const size_v = max_a[v_axis] - min_a[v_axis];

        if (size_u == 0 or size_v == 0) return .{ 0, 0 };

        const u = (p[u_axis] - min_a[u_axis]) / size_u;
        const v = (p[v_axis] - min_a[v_axis]) / size_v;

        return .{ @max(0, @min(1, u)), @max(0, @min(1, v)) };
    }
};
