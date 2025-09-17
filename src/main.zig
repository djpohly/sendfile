const std = @import("std");

const UsageError = error{Usage};

fn usage(argv0: []const u8, msg: []const u8) anyerror {
    std.debug.print(
        \\{s}
        \\Usage: {s} SRC DEST
        \\
    , .{ msg, argv0 });
    return error.Usage;
}

pub fn main() !void {
    var args = std.process.args();
    const argv0 = args.next() orelse unreachable;
    const srcpath = args.next() orelse return usage(argv0, "Source path is required");
    const dstpath = args.next() orelse return usage(argv0, "Destination path is required");
    const num_bytes = if (args.next()) |arg| try std.fmt.parseUnsigned(usize, arg, 0) else null;

    const dir = std.fs.cwd();
    const srcfile = try dir.openFileZ(srcpath, .{});
    defer srcfile.close();
    const srcstat = try srcfile.stat();
    const dstfile = try dir.createFileZ(dstpath, .{ .mode = srcstat.mode });
    defer dstfile.close();

    // No userspace buffer should be needed for sendfile()
    const no_buffer = [0]u8{};
    var source = srcfile.reader(&no_buffer);
    // Using dstfile.writer() results in error.Unimplemented (in 0.15.1)
    // (https://github.com/ziglang/zig/issues/25142?)
    var sink = dstfile.writerStreaming(&no_buffer);
    const ret = try std.fs.File.Writer.sendFile(
        &sink.interface,
        &source,
        if (num_bytes) |b| .limited(b) else .unlimited,
    );

    std.debug.print("returned {d}\n", .{ret});
}
