const std = @import("std");
const limine = @import("limine");
const BUILTIN_FONT = @import("default_font.zig").BUILTIN_FONT;

pub const TerminalCtx = struct {
    const Self = @This();
    cursor_enabled: bool,
    fb: FbCtx,
    buf: []u8,

    pub fn init(fb: *limine.Framebuffer) ?Self {
        const ctx = FbCtx.init(fb) orelse return null;
        // FIXME: Temporary fix for fmt
        const buf = bump_alloc(u8, 100) orelse return null;

        return Self {
            .fb = ctx,
            .buf = @constCast(buf),
            .cursor_enabled = false,
        };
    }

    pub fn write(self: *Self, comptime fmt: []const u8, args: anytype) void {
        const str = std.fmt.bufPrint(self.buf, fmt, args) catch @panic("fmt failed");
        for (str) |c| {
            self.write_char(c);
        }
    }

    pub fn write_char(self: *Self, c: u8) void {
        if (c >= 0x20 and c <= 0x7e) {
            self.fb.raw_putc(c);
        } else {
            self.fb.raw_putc(0xfe);
        }
    }
};


pub const FbCtx = struct {
    const Self = @This();

    pub const Vec2 = struct { x: u32, y: u32 };

    // TODO
    // const Char = struct {
    //     c: u8,
    //     fg: u32,
    //     bg: u32,
    // };
    //
    // const QueueItem = struct {
    //     x: usize,
    //     y: usize,
    //     c: Char,
    // };

    font_width: usize,
    font_height: usize,
    glyph_width: usize,
    glyph_height: usize,

    font_scale_x: usize,
    font_scale_y: usize,
    font_spacing: usize,

    framebuffer: []u32,

    pitch: usize,
    width: usize,
    height: usize,

    font: []u8,
    font_bool: []bool,

    default_bg: u32,
    default_fg: u32,
    text_bg: u32,
    text_fg: u32,

    cols: usize,
    rows: usize,

    cursor_x: usize,
    cursor_y: usize,

    offset_y: usize,
    offset_x: usize,


    pub fn init(fb: *limine.Framebuffer) ?Self {
        init_bump_alloc();
        const f_scale_x: usize = 1;
        const f_scale_y: usize = 1;
        const default_bg = 0x00000000;
        const default_fg = 0x0002FF02;

        var f_width: usize = 8;
        const f_height: usize = 16;
        const f_spacing: usize = 1;
        const font_len: usize = @divTrunc(f_width * f_height * FONT_GLYPHS, 8);
        var font_bits: []u8 = bump_alloc(u8, font_len) orelse return null;

        @memcpy(font_bits, BUILTIN_FONT);

        f_width += f_spacing;

        const bool_len = FONT_GLYPHS * f_width * f_height;
        var font_bool: []bool = bump_alloc(bool, bool_len) orelse return null;

        for (0..FONT_GLYPHS) |i| {
            const glyph: [*]u8 = @ptrCast(&font_bits[i * f_height]);

            for (0..f_height) |y| {
                for (0..8) |x| {
                    // offset basically points to the exact pixel in the glyph
                    //             start of font in bool    row + offset
                    //             ----------------------   ---------------
                    const offset = i * f_height * f_width + y * f_width + x;
                    const col: u8 = 0x80;
                    if (glyph[y] & (col >> @as(u3, @intCast(x))) > 0) {
                        font_bool[offset] = true;
                    } else {
                        font_bool[offset] = false;
                    }
                }

                for (8..f_width) |x| {
                    const offset = i * f_height * f_width + y * f_width + x;

                    if (i >= 0xc0 and i <= 0xdf) {
                        font_bool[offset] = ((glyph[y] & 1) > 0);
                    } else {
                        font_bool[offset] = false;
                    }
                }
            }
        }

        const g_height = f_height * f_scale_y;
        const g_width = f_width * f_scale_x;
        const rows = @divTrunc(fb.height, g_height);
        const cols = @divTrunc(fb.width, g_width);

        var fb_ptr: [*]u32 = @ptrCast(@alignCast(fb.address));


        return Self {
            .framebuffer = fb_ptr[0..(fb.pitch * fb.height)],
            .font_width = f_width,
            .font_height = f_height,
            .font_scale_x  = f_scale_x,
            .font_scale_y  = f_scale_y,
            .default_bg = default_bg,
            .default_fg = default_fg,
            .text_bg = default_bg,
            .text_fg = default_fg,
            .width = fb.width,
            .height = fb.height,
            .pitch = fb.pitch,
            .font = font_bits,
            .font_bool = font_bool,
            .font_spacing = f_spacing,
            .glyph_width = g_width,
            .glyph_height = g_height,
            .rows = rows,
            .cols = cols,
            .cursor_x = 0,
            .cursor_y = 0,
            .offset_y = 0,
            .offset_x = 0,
        };
    }

    pub fn get_text_color(self: *Self) Vec2 {
        return Vec2 { .x = self.text_bg, .y = self.text_fg };
    }

    pub fn get_cursor(self: *Self) Vec2 {
        return Vec2 { .x = self.cursor_x, .y = self.cursor_y };
    }

    pub fn set_cursor(self: *Self, pos: Vec2) void {
        self.cursor_x = pos.x;
        self.cursor_y = pos.y;
    }

    pub fn raw_putc(self: *Self, c: u8) void {
        if (self.cursor_x >= self.cols and self.cursor_y < self.rows) {
            self.cursor_x = 0;
            self.cursor_y += 1;
        }
        self.write_char(c);
        self.cursor_x += 1;
    }

    fn write_char(self: *Self, c: u8) void {
        const x = self.cursor_x * self.glyph_width;
        const y = self.cursor_y * self.glyph_height;

        const glyph_offset: usize = @as(usize, @intCast(c)) * self.font_height * self.font_width;
        const glyph: [*]bool = @ptrCast(&self.font_bool[glyph_offset]);

        for (0..self.glyph_height) |gy| {
            const fy: u8 = @intCast(@divTrunc(gy, self.font_scale_y));
            const fb_offset = (y + gy + self.offset_y) * self.width + x + self.offset_x;
            var fb_line: [*]u32 = @ptrCast(&self.framebuffer[fb_offset]);

            for (0..self.font_width) |fx| {
                const draw = glyph[fy * self.font_width + fx];

                for (0..self.font_scale_x) |i| {
                    const gx: usize = self.font_scale_x * fx + i;

                    if (draw) {
                        fb_line[gx] = self.text_fg;
                    } else {
                        fb_line[gx] = self.text_bg;
                    }
                }
            }
        }
    }
};

const FONT_GLYPHS: usize = 256;
const BUMP_ALLOC_POOL_SIZE: usize = 87300; // 87.3 KB
var bump_alloc_pool: [BUMP_ALLOC_POOL_SIZE]u8 = undefined;
var bump_alloc_ptr: usize = 0;
var bump_alloc_init: bool = false;

fn init_bump_alloc() void {
    if (bump_alloc_init) return;
    for (0..BUMP_ALLOC_POOL_SIZE) |i| {
        bump_alloc_pool[i] = 0;
    }

    bump_alloc_init = true;
}

fn bump_alloc(comptime T: type, size: usize) ?[]T {
    const full_size = size * @sizeOf(T);
    // TODO: proper errors maybe?
    if ((bump_alloc_ptr + full_size) > BUMP_ALLOC_POOL_SIZE) return null;
    var ptr: [*]T = @ptrCast(@constCast(@alignCast(&bump_alloc_pool[bump_alloc_ptr])));
    bump_alloc_ptr += full_size;
    return ptr[0..full_size];
}
