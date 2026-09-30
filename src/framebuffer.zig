// framebuffer.zig — Buffer de píxeles para renderizado concurrente
// Usa un rl.Image internamente. getPixels() devuelve un puntero
// al arreglo de píxeles para escritura directa desde múltiples threads.
// Cada thread escribe en filas diferentes, así que no necesita mutex.

const rl = @import("raylib");

pub const Framebuffer = struct {
    width: usize,
    height: usize,
    image: rl.Image,
    texture: ?rl.Texture = null,

    pub fn init(w: usize, h: usize) Framebuffer {
        return .{
            .width = w,
            .height = h,
            .image = rl.genImageColor(@intCast(w), @intCast(h), .black),
        };
    }

    /// Devuelve un puntero directo al buffer de píxeles.
    /// Cada píxel es un rl.Color (4 bytes: R, G, B, A).
    /// SEGURO para escritura concurrente si cada thread escribe en filas distintas.
    pub fn getPixels(self: *Framebuffer) [*]rl.Color {
        return @ptrCast(@alignCast(self.image.data));
    }

    /// Limpia toda la imagen a negro
    pub fn clear(self: *Framebuffer) void {
        self.image.clearBackground(.black);
    }

    /// Sube la imagen al GPU y la dibuja en pantalla
    pub fn swapBuffers(self: *Framebuffer) !void {
        rl.beginDrawing();
        defer rl.endDrawing();

        if (self.texture) |t| rl.unloadTexture(t);

        const tex = try rl.loadTextureFromImage(self.image);
        rl.drawTexture(tex, 0, 0, .white);
        self.texture = tex;

        // Mostrar FPS en la esquina
        rl.drawFPS(10, 10);
    }
};
