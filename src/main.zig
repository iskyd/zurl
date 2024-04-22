const std = @import("std");
const io = std.io;
const clap = @import("clap");
const request = @import("request.zig");
const storage = @import("storage.zig");

pub fn main() !void {
    std.debug.print("Zurl. Curl wrapper for json requests.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                   Display this help and exit.
        \\-m, --method <HTTP_METHOD>   An option parameter, which takes the http method
        \\-q, --query <STR>...         Query params
        \\--header <STR>...            Headers
        \\-s, --save <STR>             Save the current request
        \\-f, --find <STR>             Find the current request
        \\-d, --delete <STR>           Delete the current request
        \\-l, --list                   List all saved requests
        \\--db <STR>                   Database name
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
        .allocator = allocator,
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
        try storage.init(res.args.db.?);
        return;
    }

    if (res.args.list != 0) {
        try storage.list(res.args.db.?);
        return;
    }

    if (res.args.find) |rn| {
        const httpreq = storage.get(allocator, res.args.db.?, rn) catch |err| switch (err) {
            error.NotFound => {
                std.debug.print("Request not found", .{});
                return;
            },
            else => return err,
        };
        defer allocator.free(httpreq.url);
        defer {
            if (httpreq.params != null) {
                for (httpreq.params.?) |p| {
                    allocator.free(p.key);
                    allocator.free(p.value);
                }
                allocator.free(httpreq.params.?);
            }
        }
        std.debug.print("Url: {s}\n", .{httpreq.url});
        std.debug.print("Methodsss: {s}\n", .{@tagName(httpreq.method)});
        if (httpreq.params != null and httpreq.params.?.len > 0) {
            for (httpreq.params.?) |p| {
                std.debug.print("Param: {s}={s}\n", .{ p.key, p.value });
            }
        }
        return;
    }

    if (res.args.delete) |rn| {
        try storage.delete(res.args.db.?, rn);
        std.debug.print("Request deleted\n", .{});
        return;
    }

    std.debug.assert(res.positionals.len == 1); // url must exist

    const method: request.HttpRequestMethod = if (res.args.method) |m| m else request.HttpRequestMethod.GET;

    var queryparams = try allocator.alloc(request.QueryParam, res.args.query.len);
    defer allocator.free(queryparams);
    for (res.args.query, 0..) |q, i| {
        var it = std.mem.split(u8, q, "=");
        queryparams[i] = request.QueryParam{ .key = it.next().?, .value = it.next().? };
        std.debug.print("--query = {s}\n", .{q});
    }

    var headers = try allocator.alloc(request.Header, res.args.header.len);
    defer allocator.free(headers);
    for (res.args.header, 0..) |q, i| {
        var it = std.mem.split(u8, q, "=");
        headers[i] = request.Header{ .key = it.next().?, .value = it.next().? };
        std.debug.print("--header = {s}\n", .{q});
    }

    var url: []const u8 = res.positionals[0];
    const req = request.HttpRequest{ .url = url, .method = method, .params = queryparams, .headers = headers };

    if (res.args.save) |rn| {
        try storage.save(allocator, res.args.db.?, rn, req);
    }

    try request.execute(allocator, req);
}
