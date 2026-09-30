// camera.zig — Cámara orbital con lookAt
// La cámara orbita alrededor de un punto objetivo.
// Genera los vectores Forward, Right, Up para transformar
// las direcciones de los rayos del espacio de cámara al espacio del mundo.

const rl = @import("raylib");

pub const Camera = struct {
    // Nota: "Postition" mantiene el typo del código base por compatibilidad
    Postition: rl.Vector3,
    Forward: rl.Vector3,
    Right: rl.Vector3,
    Up: rl.Vector3,

    pub fn init(position: rl.Vector3, target: rl.Vector3) Camera {
        var out = Camera{
            .Forward = .zero(),
            .Postition = position,
            .Right = .{ .x = 1, .y = 0, .z = 0 },
            .Up = .{ .x = 0, .y = 1, .z = 0 },
        };
        out.lookAt(target);
        return out;
    }

    /// Recalcula los vectores de orientación para apuntar al target
    pub fn lookAt(self: *Camera, target: rl.Vector3) void {
        // Forward: dirección de la cámara al objetivo
        self.Forward = target.subtract(self.Postition).normalize();

        // Right: perpendicular a Forward y Up (producto cruz)
        self.Right = rl.Vector3.crossProduct(self.Up, self.Forward).normalize();

        // Up: perpendicular a Forward y Right (corrige acumulación de error)
        self.Up = rl.Vector3.crossProduct(self.Forward, self.Right).normalize();
    }
};
