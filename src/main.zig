const std = @import("std");
const limine = @import("limine");
const terminal = @import("terminal.zig");

// pub export var module_request: limine.ModuleRequest = .{};
pub export var framebuffer_request: limine.FramebufferRequest = .{};

pub export var base_revision: limine.BaseRevision = .{ .revision = 1 };

inline fn done() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}


export fn _start() callconv(.C) noreturn {
    if (!base_revision.is_supported()) done();

    // Ensure we got a framebuffer.
    if (framebuffer_request.response) |framebuffer_response| {
        if (framebuffer_response.framebuffer_count < 1) {
            done();
        }

        // Get the first framebuffer's information.
        const framebuffer = framebuffer_response.framebuffers()[0];

        const fb_ctx = terminal.FbCtx.init(framebuffer);
        if (fb_ctx) |ctx| {
            @constCast(&ctx).raw_putc('H');
            @constCast(&ctx).raw_putc('e');
            @constCast(&ctx).raw_putc('l');
            @constCast(&ctx).raw_putc('l');
            @constCast(&ctx).raw_putc('o');
            @constCast(&ctx).raw_putc('!');
        } else {
            for (0..100) |i| {
                // Calculate the pixel offset using the framebuffer information we obtained above.
                // We skip `i` scanlines (pitch is provided in bytes) and add `i * 4` to skip `i` pixels forward.
                const pixel_offset = i * framebuffer.width;

                // Write 0xFFFFFFFF to the provided pixel offset to fill it white.
                @as(*u32, @ptrCast(@alignCast(framebuffer.address + pixel_offset))).* = 0xFFFFFFFF;
            }
        }
    }

    done();
}
