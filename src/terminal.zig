const std = @import("std");
const limine = @import("limine");

const TerminalCtx = struct {
    cursor_enabled: bool,
};

pub const FbCtx = struct {
    const Self = @This();
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


    pub fn init(fb: *limine.Framebuffer) ?Self {
        init_bump_alloc();
        const f_scale_x: usize = 1;
        const f_scale_y: usize = 1;
        const default_bg = 0x00000000;
        const default_fg = 0x00AAAAAA;

        var font_bits: []u8 = undefined;
        var f_width: usize = 8;
        const f_height: usize = 16;
        const f_spacing: usize = 1;
        const font_len: usize = @divTrunc(f_width * f_height * FONT_GLYPHS, 8);
        if (bump_alloc(u8, font_len)) |ptr| {
            font_bits = ptr;
        } else {
            return null;
        }

        @memcpy(font_bits, BUILTIN_FONT);

        f_width += f_spacing;

        var font_bool: []bool = undefined;
        if (bump_alloc(bool, FONT_GLYPHS * f_width * f_height)) |ptr| {
            font_bool = ptr;
        } else {
            return null;
        }

        for (0..FONT_GLYPHS) |i| {
            const glyph: [*]u8 = @ptrCast(&font_bits[i * f_height]);

            for (0..f_height) |y| {
                for (0..8) |x| {
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

        var fb_ptr: [*]u32 = @ptrCast(@alignCast(fb.address));

        return Self {
            .framebuffer = fb_ptr[0..(fb.pitch * fb.height)],
            .font_width = f_width,
            .font_height = f_height,
            .font_scale_x  = f_scale_x,
            .font_scale_y  = f_scale_y,
            .default_bg = default_bg,
            .default_fg = default_fg,
            .text_bg = 0xFFFFFFFF,
            .text_fg = default_fg,
            .width = fb.width,
            .height = fb.height,
            .pitch = fb.pitch,
            .font = font_bits,
            .font_bool = font_bool,
            .font_spacing = f_spacing,
            .glyph_width = g_width,
            .glyph_height = g_height,
            .rows = @divTrunc(f_height, g_height),
            .cols = @divTrunc(f_width, g_width),
            .cursor_x = 0,
            .cursor_y = 0,
        };
    }

    pub fn raw_putc(self: *Self, c: u8) void {
        const x = self.cursor_x * self.glyph_width;
        const y = self.cursor_y * self.glyph_height;

        const glyph_offset: usize = @as(usize, @intCast(c)) * self.font_height * self.font_width;
        const glyph: [*] bool = @ptrCast(&self.font_bool[glyph_offset]);

        for (0..self.glyph_height) |gy| {
            const fy: u8 = @intCast(@divTrunc(gy, self.font_scale_y));
            const fb_offset = x + (y + gy) * (self.pitch / 4);
            var fb_line: [*]u32 = @ptrCast(@alignCast(&self.framebuffer[fb_offset]));

            for (0..self.font_width) |fx| {
                const draw = glyph[fy * self.font_width + fx];

                for (0..self.font_scale_x) |i| {
                    const gx: usize = self.font_scale_x * fx + i;

                    if (draw) {
                        fb_line[gx] = self.text_fg;
                    } else {
                        fb_line[gx] = self.default_bg;
                    }
                }
            }
        }
        self.cursor_x += 1;
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

const BUILTIN_FONT: []u8 =  @constCast(&[_]u8{
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x3c, 0x42, 0x81, 0x81, 0xa5, 0xa5, 0x81,
  0x81, 0xa5, 0x99, 0x81, 0x42, 0x3c, 0x00, 0x00, 0x00, 0x3c, 0x7e, 0xff,
  0xff, 0xdb, 0xdb, 0xff, 0xff, 0xdb, 0xe7, 0xff, 0x7e, 0x3c, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x6c, 0xfe, 0xfe, 0xfe, 0x7c, 0x7c, 0x38, 0x38, 0x10,
  0x10, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x38, 0x38, 0x7c, 0x7c, 0xfe,
  0x7c, 0x7c, 0x38, 0x38, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18,
  0x3c, 0x3c, 0xdb, 0xff, 0xff, 0xdb, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x18, 0x3c, 0x7e, 0xff, 0xff, 0xff, 0x66, 0x18, 0x18,
  0x3c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x78,
  0x78, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xe7, 0xc3, 0xc3, 0xe7, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x78, 0xcc, 0x84, 0x84, 0xcc, 0x78, 0x00,
  0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xc3, 0x99, 0xbd,
  0xbd, 0x99, 0xc3, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x1e,
  0x0e, 0x1e, 0x32, 0x78, 0xcc, 0xcc, 0xcc, 0x78, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x78, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0xfc, 0x30, 0x30,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x18, 0x1c, 0x1e, 0x16, 0x12,
  0x10, 0x10, 0x70, 0xf0, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x30, 0x38, 0x2c,
  0x26, 0x32, 0x3a, 0x2e, 0x26, 0x22, 0x62, 0xe2, 0xc6, 0x0e, 0x0c, 0x00,
  0x00, 0x00, 0x00, 0x18, 0x18, 0xdb, 0x3c, 0xe7, 0x3c, 0xdb, 0x18, 0x18,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0xc0, 0xe0, 0xf8, 0xfe,
  0xf8, 0xe0, 0xc0, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
  0x06, 0x0e, 0x3e, 0xfe, 0x3e, 0x0e, 0x06, 0x02, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x30, 0x78, 0xfc, 0x30, 0x30, 0x30, 0x30, 0x30, 0xfc, 0x78,
  0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc,
  0xcc, 0xcc, 0x00, 0xcc, 0xcc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7f, 0xdb,
  0xdb, 0xdb, 0xdb, 0x7b, 0x1b, 0x1b, 0x1b, 0x1b, 0x1b, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0x60, 0x38, 0x6c, 0xc6, 0xc6, 0x6c, 0x38, 0x0c,
  0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xfe, 0xfe, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x78,
  0xfc, 0x30, 0x30, 0x30, 0x30, 0x30, 0xfc, 0x78, 0x30, 0xfc, 0x00, 0x00,
  0x00, 0x00, 0x30, 0x78, 0xfc, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
  0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
  0x30, 0x30, 0xfc, 0x78, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x18, 0x0c, 0xfe, 0xfe, 0x0c, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x60, 0xfe, 0xfe, 0x60, 0x30, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0,
  0xc0, 0xc0, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x24, 0x66, 0xff, 0xff, 0x66, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x38, 0x38, 0x7c, 0x7c, 0xfe, 0xfe,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xfe, 0x7c, 0x7c,
  0x38, 0x38, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x30, 0x78, 0x78, 0x78, 0x78, 0x30, 0x30, 0x30, 0x00, 0x30,
  0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x6c,
  0x6c, 0xfe, 0x6c, 0x6c, 0x6c, 0xfe, 0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00,
  0x00, 0x18, 0x18, 0x7c, 0xc6, 0xc0, 0xc0, 0x7c, 0x06, 0x06, 0xc6, 0x7c,
  0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0x0c, 0x0c, 0x18, 0x38,
  0x30, 0x60, 0x60, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c,
  0x6c, 0x38, 0x30, 0x76, 0xde, 0xcc, 0xcc, 0xde, 0x76, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x18, 0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x30, 0x60, 0x60, 0x60, 0x60,
  0x60, 0x60, 0x60, 0x30, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x30,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x30, 0x60, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x38, 0xfe, 0x38, 0x6c, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x7e,
  0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06,
  0x0c, 0x0c, 0x18, 0x38, 0x30, 0x60, 0x60, 0xc0, 0xc0, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xd6, 0xd6, 0xd6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x38, 0x78, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6,
  0x06, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0xc0, 0xfe, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0x06, 0x06, 0x3c, 0x06, 0x06, 0x06, 0x06, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x0c, 0x1c, 0x3c, 0x6c, 0xcc,
  0xfe, 0x0c, 0x0c, 0x0c, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xc0,
  0xc0, 0xc0, 0xfc, 0x06, 0x06, 0x06, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x3c, 0x60, 0xc0, 0xc0, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xc6, 0x06, 0x06, 0x0c, 0x18,
  0x30, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6,
  0xc6, 0xc6, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0x06, 0x06, 0x0c,
  0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18,
  0x18, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30, 0x00, 0x00,
  0x00, 0x00, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x60, 0x30, 0x18, 0x0c,
  0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0x00,
  0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x60,
  0x30, 0x18, 0x0c, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0xc6, 0x06, 0x0c, 0x18, 0x30, 0x30, 0x00, 0x30,
  0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xde, 0xde,
  0xde, 0xde, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c,
  0xc6, 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc0, 0xc0, 0xc0,
  0xc0, 0xc0, 0xc0, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0xcc,
  0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xcc, 0xf8, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xfe, 0xc0, 0xc0, 0xc0, 0xfc, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
  0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xc0, 0xc0, 0xc0, 0xfc, 0xc0,
  0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6,
  0xc0, 0xc0, 0xc0, 0xde, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0xc6,
  0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0x30, 0x30, 0x30, 0x30, 0x30,
  0x30, 0x30, 0x30, 0x30, 0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1e, 0x0c,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xc6, 0xc6, 0xcc, 0xd8, 0xf0, 0xe0, 0xf0, 0xd8, 0xcc, 0xc6,
  0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
  0xc0, 0xc0, 0xc0, 0xc0, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6,
  0xee, 0xfe, 0xd6, 0xd6, 0xd6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xc6, 0xc6, 0xe6, 0xe6, 0xf6, 0xde, 0xce, 0xce, 0xc6, 0xc6,
  0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0xc6,
  0xc6, 0xc6, 0xc6, 0xfc, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xf6, 0xda,
  0x6c, 0x06, 0x00, 0x00, 0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xfc,
  0xd8, 0xcc, 0xcc, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6,
  0xc0, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xd6, 0xd6, 0xd6, 0xd6, 0xfe, 0x6c,
  0x6c, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x38,
  0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0xcc, 0xcc,
  0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xfe, 0x06, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0xc0, 0xc0,
  0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x78, 0x60, 0x60, 0x60, 0x60, 0x60,
  0x60, 0x60, 0x60, 0x60, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0xc0,
  0x60, 0x60, 0x30, 0x38, 0x18, 0x0c, 0x0c, 0x06, 0x06, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x78, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0x00,
  0x00, 0x00, 0x18, 0x18, 0x18, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0x06, 0x06,
  0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0xc0,
  0xc0, 0xdc, 0xe6, 0xc6, 0xc6, 0xc6, 0xc6, 0xe6, 0xdc, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc0, 0xc0, 0xc0, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06, 0x06, 0x76, 0xce, 0xc6,
  0xc6, 0xc6, 0xc6, 0xce, 0x76, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x7c, 0xc6, 0xc6, 0xfe, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x1c, 0x36, 0x30, 0x30, 0xfc, 0x30, 0x30, 0x30, 0x30, 0x30,
  0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x76, 0xce, 0xc6,
  0xc6, 0xc6, 0xce, 0x76, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0xc0, 0xc0,
  0xc0, 0xdc, 0xe6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x18, 0x00, 0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x3c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x1e, 0x06, 0x06,
  0x06, 0x06, 0x06, 0x06, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0xc0, 0xc0,
  0xc0, 0xc6, 0xcc, 0xd8, 0xf0, 0xf0, 0xd8, 0xcc, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x3c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xec, 0xfe, 0xd6,
  0xd6, 0xd6, 0xd6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0xdc, 0xe6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xdc, 0xe6, 0xc6,
  0xc6, 0xc6, 0xe6, 0xdc, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x76, 0xce, 0xc6, 0xc6, 0xc6, 0xce, 0x76, 0x06, 0x06, 0x06, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0xdc, 0xe6, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0,
  0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc0,
  0x70, 0x1c, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30,
  0x30, 0xfe, 0x30, 0x30, 0x30, 0x30, 0x30, 0x36, 0x1c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0xc6, 0xc6, 0xd6, 0xd6, 0xd6, 0xd6, 0xfe, 0x6c, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0x6c, 0x38, 0x38, 0x6c, 0xc6,
  0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xce, 0x76, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0xfe, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0xfe, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x1c, 0x30, 0x30, 0x30, 0x30, 0xe0, 0x30, 0x30, 0x30, 0x30,
  0x1c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x00,
  0x30, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0xe0, 0x30,
  0x30, 0x30, 0x30, 0x1c, 0x30, 0x30, 0x30, 0x30, 0xe0, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x38, 0x38, 0x6c,
  0x6c, 0xc6, 0xc6, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3c, 0x66,
  0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x66, 0x3c, 0x18, 0xcc, 0x78, 0x00,
  0x00, 0x00, 0x6c, 0x6c, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x18, 0x30, 0x00, 0x7c, 0xc6, 0xc6,
  0xfe, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x10, 0x38, 0x6c,
  0x00, 0x7c, 0x06, 0x06, 0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x6c, 0x6c, 0x00, 0x7c, 0x06, 0x06, 0x7e, 0xc6, 0xc6, 0xc6,
  0x7e, 0x00, 0x00, 0x00, 0x00, 0x60, 0x30, 0x18, 0x00, 0x7c, 0x06, 0x06,
  0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c, 0x38,
  0x00, 0x7c, 0x06, 0x06, 0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc0, 0xc0, 0xc0, 0xc6,
  0x7c, 0x18, 0x0c, 0x38, 0x00, 0x10, 0x38, 0x6c, 0x00, 0x7c, 0xc6, 0xc6,
  0xfe, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x6c,
  0x00, 0x7c, 0xc6, 0xc6, 0xfe, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00,
  0x00, 0x60, 0x30, 0x18, 0x00, 0x7c, 0xc6, 0xc6, 0xfe, 0xc0, 0xc0, 0xc0,
  0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x6c, 0x00, 0x38, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x00, 0x00, 0x10, 0x38, 0x6c,
  0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x00,
  0x00, 0x60, 0x30, 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x3c, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0x10, 0x38, 0x6c, 0xc6, 0xc6, 0xc6,
  0xfe, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x38, 0x6c, 0x38, 0x00,
  0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x18, 0x30, 0x60, 0x00, 0xfe, 0xc0, 0xc0, 0xfc, 0xc0, 0xc0, 0xc0, 0xc0,
  0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xec, 0x36, 0x36,
  0x76, 0xde, 0xd8, 0xd8, 0x6e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1e, 0x3c,
  0x6c, 0xcc, 0xcc, 0xfe, 0xcc, 0xcc, 0xcc, 0xcc, 0xce, 0x00, 0x00, 0x00,
  0x00, 0x10, 0x38, 0x6c, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x6c, 0x00, 0x7c, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x60, 0x30, 0x18,
  0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00,
  0x00, 0x10, 0x38, 0x6c, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x60, 0x30, 0x18, 0x00, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6c, 0x6c,
  0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xce, 0x76, 0x06, 0xc6, 0x7c, 0x00,
  0x6c, 0x6c, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x6c, 0x6c, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30,
  0x30, 0x78, 0xcc, 0xc0, 0xc0, 0xcc, 0x78, 0x30, 0x30, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x38, 0x6c, 0x60, 0x60, 0x60, 0xf8, 0x60, 0x60, 0x60, 0xe6,
  0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0xfc,
  0x30, 0xfc, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0xcc,
  0xcc, 0xf8, 0xc4, 0xcc, 0xde, 0xcc, 0xcc, 0xcc, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x0e, 0x1b, 0x18, 0x18, 0x18, 0x7e, 0x18, 0x18, 0x18, 0x18,
  0x18, 0xd8, 0x70, 0x00, 0x00, 0x0c, 0x18, 0x30, 0x00, 0x7c, 0x06, 0x06,
  0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x18, 0x30,
  0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x00,
  0x00, 0x0c, 0x18, 0x30, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x18, 0x30, 0x00, 0xc6, 0xc6, 0xc6,
  0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x76, 0xdc, 0x00,
  0x00, 0xdc, 0xe6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x76, 0xdc, 0x00, 0xc6, 0xc6, 0xe6, 0xf6, 0xfe, 0xde, 0xce, 0xc6, 0xc6,
  0xc6, 0x00, 0x00, 0x00, 0x00, 0x78, 0xd8, 0xd8, 0x6c, 0x00, 0xfc, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c, 0x6c,
  0x38, 0x00, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x30, 0x60, 0xc0, 0xc6, 0xc6,
  0x7c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0xfe, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0xfe, 0x06, 0x06, 0x06, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xc0, 0xc2, 0xc6, 0xcc, 0xd8, 0x30, 0x60, 0xdc, 0x86, 0x0c,
  0x18, 0x3e, 0x00, 0x00, 0x00, 0x00, 0xc0, 0xc2, 0xc6, 0xcc, 0xd8, 0x30,
  0x66, 0xce, 0x9e, 0x3e, 0x06, 0x06, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30,
  0x00, 0x30, 0x30, 0x30, 0x78, 0x78, 0x78, 0x78, 0x30, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x6c, 0xd8, 0x6c, 0x36, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd8, 0x6c, 0x36,
  0x6c, 0xd8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x22, 0x88, 0x22, 0x88,
  0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88,
  0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa,
  0x55, 0xaa, 0x55, 0xaa, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77,
  0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf8, 0xf8, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf8, 0xf8, 0x18,
  0x18, 0xf8, 0xf8, 0x18, 0x18, 0x18, 0x18, 0x18, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0xf6, 0xf6, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xfe, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0xf8, 0x18,
  0x18, 0xf8, 0xf8, 0x18, 0x18, 0x18, 0x18, 0x18, 0x36, 0x36, 0x36, 0x36,
  0x36, 0xf6, 0xf6, 0x06, 0x06, 0xf6, 0xf6, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0xfe, 0x06,
  0x06, 0xf6, 0xf6, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0xf6, 0xf6, 0x06, 0x06, 0xfe, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0xfe, 0xfe, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf8, 0xf8, 0x18,
  0x18, 0xf8, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0xf8, 0xf8, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x1f, 0x1f, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xff,
  0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0xff, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x1f, 0x1f, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff,
  0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0xff, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x1f, 0x1f, 0x18, 0x18, 0x1f, 0x1f, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x37,
  0x37, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x37, 0x37, 0x30, 0x30, 0x3f, 0x3f, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x3f, 0x3f, 0x30, 0x30, 0x37, 0x37, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0xf7, 0xf7, 0x00,
  0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0xff, 0xff, 0x00, 0x00, 0xf7, 0xf7, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x36, 0x37, 0x37, 0x30, 0x30, 0x37, 0x37, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0x00,
  0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x36, 0x36, 0x36,
  0x36, 0xf7, 0xf7, 0x00, 0x00, 0xf7, 0xf7, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x18, 0x18, 0x18, 0x18, 0x18, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0xff,
  0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x3f,
  0x3f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x1f, 0x1f, 0x18, 0x18, 0x1f, 0x1f, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x1f, 0x18, 0x18, 0x1f, 0x1f, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3f,
  0x3f, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x36, 0x36, 0x36, 0xff, 0xff, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
  0x18, 0x18, 0x18, 0x18, 0x18, 0xff, 0xff, 0x18, 0x18, 0xff, 0xff, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf8,
  0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x1f, 0x1f, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xf0, 0xf0, 0xf0, 0xf0,
  0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0,
  0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f,
  0x0f, 0x0f, 0x0f, 0x0f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x76, 0xd6, 0xdc, 0xc8, 0xc8, 0xdc, 0xd6, 0x76, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x78, 0xcc, 0xcc, 0xcc, 0xd8, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc,
  0xd8, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0xfe, 0xc6, 0xc6, 0xc0, 0xc0, 0xc0,
  0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x7e, 0xfe, 0x24, 0x24, 0x24, 0x24, 0x66, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0xfe, 0xfe, 0xc2, 0x60, 0x30, 0x18, 0x30, 0x60, 0xc2, 0xfe,
  0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc8, 0xcc,
  0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x76, 0x6c, 0x60, 0xc0, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x66, 0xfc, 0x98, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0x30, 0x30, 0x78, 0xcc, 0xcc,
  0xcc, 0x78, 0x30, 0x30, 0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c,
  0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x6c, 0x6c,
  0xee, 0x00, 0x00, 0x00, 0x00, 0x00, 0x78, 0xcc, 0x60, 0x30, 0x78, 0xcc,
  0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x76, 0xbb, 0x99, 0x99, 0xdd, 0x6e, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x02, 0x06, 0x3c, 0x6c, 0xce, 0xd6, 0xd6, 0xe6, 0x6c, 0x78,
  0xc0, 0x80, 0x00, 0x00, 0x00, 0x00, 0x1e, 0x30, 0x60, 0xc0, 0xc0, 0xfe,
  0xc0, 0xc0, 0x60, 0x30, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c,
  0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0xfe, 0x00, 0x00, 0xfe, 0x00, 0x00, 0xfe, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0xfc,
  0x30, 0x30, 0x00, 0x00, 0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x60, 0x30, 0x18, 0x0c, 0x18, 0x30, 0x60, 0x00, 0xfc, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x18, 0x30, 0x60, 0xc0, 0x60, 0x30, 0x18, 0x00,
  0xfc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1c, 0x36, 0x36, 0x30, 0x30, 0x30,
  0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x18, 0x18, 0x18, 0x18,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xd8, 0xd8, 0x70, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, 0xfc, 0x00, 0x30, 0x30, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x76, 0xdc, 0x00,
  0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x78, 0xcc, 0xcc,
  0xcc, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x0c, 0x0c,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0xcc, 0x6c, 0x3c, 0x1c, 0x0c, 0x00, 0x00,
  0x00, 0xd8, 0xec, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x6c, 0x0c, 0x18, 0x30, 0x60, 0x7c,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x78, 0x78, 0x78, 0x78, 0x78, 0x78, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00
});