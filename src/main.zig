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
        \\--filter <STR>               Search for specific request
        \\-j, --json <STR>             Json request
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
        try storage.list(allocator, res.args.db.?, res.args.filter);
        return;
    }

    if (res.args.delete) |rn| {
        try storage.delete(res.args.db.?, rn);
        std.debug.print("Request deleted\n", .{});
        return;
    }

    var httpreq: request.HttpRequest = undefined;
    if (res.args.find) |rn| {
        httpreq = storage.get(allocator, res.args.db.?, rn) catch |err| switch (err) {
            error.NotFound => {
                std.debug.print("Request not found", .{});
                return;
            },
            else => return err,
        };
        std.debug.print("Url in if {s}\n", .{httpreq.url});
    } else {
        std.debug.assert(res.positionals.len == 1); // url must exist

        const url: []const u8 = res.positionals[0];
        const method: request.HttpRequestMethod = if (res.args.method) |m| m else request.HttpRequestMethod.GET;
        var queryparams = try allocator.alloc(request.QueryParam, res.args.query.len);
        for (res.args.query, 0..) |q, i| {
            var it = std.mem.split(u8, q, "=");
            queryparams[i] = request.QueryParam{ .key = it.next().?, .value = it.next().? };
        }
        var headers = try allocator.alloc(request.Header, res.args.header.len);
        for (res.args.header, 0..) |q, i| {
            var it = std.mem.split(u8, q, "=");
            headers[i] = request.Header{ .key = it.next().?, .value = it.next().? };
        }
        var json: ?[]u8 = null;
        if (res.args.json) |v| {
            json = try allocator.alloc(u8, v.len);
            std.mem.copy(u8, json.?[0..], v);
        }
        httpreq = request.HttpRequest{ .url = url, .method = method, .params = queryparams, .headers = headers, .json = json };

        if (res.args.save) |rn| {
            try storage.save(allocator, res.args.db.?, rn, httpreq);
        }
    }

    defer {
        if (res.args.find != null) {
            allocator.free(httpreq.url);
        }
    }
    defer {
        if (httpreq.params != null) {
            if (res.args.find != null) {
                for (httpreq.params.?) |p| {
                    allocator.free(p.key);
                    allocator.free(p.value);
                }
            }
            allocator.free(httpreq.params.?);
        }
    }
    defer {
        if (httpreq.headers != null) {
            if (res.args.find != null) {
                for (httpreq.headers.?) |h| {
                    allocator.free(h.key);
                    allocator.free(h.value);
                }
            }
            allocator.free(httpreq.headers.?);
        }
    }
    defer {
        if (httpreq.json != null) {
            allocator.free(httpreq.json.?);
        }
    }

    std.debug.print("{}\n", .{httpreq});
    try request.execute(allocator, httpreq);
}
