const std = @import("std");
const io = std.io;
const clap = @import("clap");
const request = @import("request.zig");
const storage = @import("storage.zig");

const DB_NAME = "test.db";

pub fn main() !void {
    std.debug.print("Zurl. Curl wrapper for json requests.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                   Display this help and exit.
        \\-m, --method <HTTP_METHOD>   An option parameter, which takes the http method    
        \\-s, --save                   Save the current request
        \\--requestname <STR> Save the current request using name
        \\--init                       Init
        \\<URL>...
    );

    const parsers = comptime .{
        .HTTP_METHOD = clap.parsers.enumeration(request.HttpRequestMethod),
        .URL = clap.parsers.string,
        .STR = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
    }

    if (res.args.init != 0) {
        try storage.init(DB_NAME);
        return;
    }

    std.debug.assert(res.positionals.len == 1);
    const method: request.HttpRequestMethod = if (res.args.method) |m| m else request.HttpRequestMethod.GET;
    var url: []const u8 = res.positionals[0];

    if (res.args.save != 0) {
        var reqname = url;
        if (res.args.requestname) |rn| {
            reqname = rn;
        }
        try storage.save(DB_NAME, reqname, @tagName(method), url);
    }

    const req = request.HttpRequest{ .url = url, .method = method };
    request.execute(req);
}
