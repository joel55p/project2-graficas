// formas.zig — Union de todas las formas geométricas
// Permite tener un arreglo mixto de esferas y cubos.

const Sphere = @import("sphere.zig").Sphere;
const Cube = @import("cube.zig").Cube;
const Intersect = @import("raytracer.zig").Intersect;
const rl = @import("raylib");

const Tipo = enum {
    Sphere,
    Cube,
};

pub const Forma = union(Tipo) {
    Sphere: Sphere,
    Cube: Cube,

    /// Despacha la intersección a la forma correspondiente
    pub fn intersect(self: Forma, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        return switch (self) {
            .Sphere => |s| s.intersect(origin, direction),
            .Cube => |c| c.intersect(origin, direction),
        };
    }
};
