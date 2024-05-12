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
    kernel.setLinkerScriptPath(.{ .path = "linker.ld" });

    b.installArtifact(kernel);
    const iso_step = b.step("iso", "Build iso");
    iso_step.dependOn(&kernel.step);

    const iso_cmd = b.addSystemCommand(&[_][]const u8{"./iso.sh"});

    const run = b.addSystemCommand(&[_][]const u8{"./run.sh"});
    run.step.dependOn(&iso_cmd.step);

    const run_step = b.step("run", "Run kernel on QEMU");
    run_step.dependOn(&run.step);

    const debug = b.addSystemCommand(&[_][]const u8{"./db.sh"});
    debug.step.dependOn(&iso_cmd.step);

    const debug_step = b.step("debug", "Debug kernel on QEMU");
    debug_step.dependOn(&debug.step);
}
