const std = @import("std");
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Feature = std.Target.Cpu.Feature;
const Compile = std.Build.Step.Compile;

var target_arch = CrossTarget {
    .cpu_arch = .x86_64,
    .os_tag = .freestanding,
    .abi = .none,
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const features = Target.x86.Feature;
    target_arch.cpu_features_sub.addFeature(@intFromEnum(features.mmx));
    target_arch.cpu_features_sub.addFeature(@intFromEnum(features.sse));
    target_arch.cpu_features_sub.addFeature(@intFromEnum(features.sse2));
    target_arch.cpu_features_sub.addFeature(@intFromEnum(features.avx));
    target_arch.cpu_features_sub.addFeature(@intFromEnum(features.avx2));
    target_arch.cpu_features_add.addFeature(@intFromEnum(features.soft_float));


    const target = b.resolveTargetQuery(target_arch);
    const optimize = b.standardOptimizeOption(.{});
    const limine = b.dependency("limine", .{});

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
        .pic = true,
    });
    
    kernel.root_module.addImport("limine", limine.module("limine"));
    kernel.setLinkerScriptPath(.{ .path = "src/linker.ld" });

    b.installArtifact(kernel);
    //
    // const kernel_step = b.step("kernel", "Build the kernel");
    // kernel_step.dependOn(&kernel.step);
    //
    // const iso_dir = b.fmt("{s}/iso_root", .{b.cache_root.path.?});
    // const kernel_path = b.fmt("{s}/{s}", .{b.exe_dir, kernel.out_filename});
    // const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});
    //
    // const iso_cmd_str = &[_][]const u8{
    //     "/bin/sh", "-c",
    //     std.mem.concat(b.allocator, u8, &[_][] const u8 {
    //         "mkdir -p ", iso_dir, "/boot/grub", " && ",
    //         "cp ", kernel_path, " ", iso_dir, "/boot/kernel.elf", " && ",
    //         "cp src/grub.cfg ", iso_dir, "/boot/grub/grub.cfg", " && ",
    //         "grub-mkrescue -o ", iso_path, " ", iso_dir
    //     }) catch @panic("OOM")
    // };
    //
    // const iso_cmd = b.addSystemCommand(iso_cmd_str);
    // iso_cmd.step.dependOn(kernel_step);
    //
    // const iso_step = b.step("iso", "Build an ISO image");
    // iso_step.dependOn(&iso_cmd.step);
    //
    // b.default_step.dependOn(iso_step);
    //
    // const run_cmd_str = &[_][] const u8 {
    //     "qemu-system-x86_64",
    //     "-cdrom", iso_path,
    //     "-debugcon", "stdio",
    //     "-vga", "virtio",
    //     "-m", "4G",
    //     "-machine", "q35,accel=kvm:whpx:tcg",
    //     "-no-reboot", "-no-shutdown"
    // };
    //
    // const run_cmd = b.addSystemCommand(run_cmd_str);
    // run_cmd.step.dependOn(b.getInstallStep());
    //
    // const run_step = b.step("run", "Run the kernel");
    // run_step.dependOn(&run_cmd.step);
}
