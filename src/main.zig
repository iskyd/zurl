const std = @import("std");
const io = std.io;
const curl = @cImport(@cInclude("curl/curl.h"));
const c = @cImport(@cInclude("stddef.h"));
const clap = @import("clap");
const request = @import("request.zig");
const http = std.http;

pub fn main() !void {
    std.debug.print("Zurl. Curl wrapper for json requests.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                   Display this help and exit.
        \\-m, --method <HTTP_METHOD>   An option parameter, which takes the http method    
        \\<URL>...
    );

    const parsers = comptime .{
        .HTTP_METHOD = clap.parsers.enumeration(request.HttpRequestMethod),
        .URL = clap.parsers.string,
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

    if (res.args.method) |m|
        std.debug.print("--method = {s}\n", .{@tagName(m)});

    std.debug.assert(res.positionals.len == 1);

    var url: []const u8 = res.positionals[0];
    std.debug.print("Url: {s}\n", .{url});

    _ = curl.curl_global_init(curl.CURL_GLOBAL_DEFAULT);

    switch (res.args.method.?) {
        request.HttpRequestMethod.GET => {
            const handler = curl.curl_easy_init();
            // var headers = curl.curl_slist_append(h)
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, url.ptr);
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, )
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POST, "");
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, c.NULL);
            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
        },
        else => {
            std.debug.print("Method not supported yet\n", .{});
            unreachable;
        },
    }

    //if (http_res != curl.CURLE_OK) {
    //std.debug.print("Error while executing request", .{});
    //} else {
    //std.debug.print("Request executed", .{});
    //}

}
