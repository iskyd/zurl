const std = @import("std");
const curl = @cImport(@cInclude("curl/curl.h"));
const c = @cImport(@cInclude("stddef.h"));

pub const HttpRequestMethod = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTIONS,
};

pub const QueryParam = struct { key: []u8, value: []u8 };

pub const HttpRequest = struct {
    method: HttpRequestMethod,
    url: []const u8,
    params: ?[]QueryParam = null,
    json: ?[]u8 = null,
};

pub fn execute(req: HttpRequest) void {
    _ = curl.curl_global_init(curl.CURL_GLOBAL_DEFAULT);
    switch (req.method) {
        HttpRequestMethod.GET => {
            const handler = curl.curl_easy_init();
            // var headers = curl.curl_slist_append(h)
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, req.url.ptr);
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, )
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POST, "");
            // _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, c.NULL);
            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
            //if (http_res != curl.CURLE_OK) {
            //std.debug.print("Error while executing request", .{});
            //} else {
            //std.debug.print("Request executed", .{});
            //}
        },
        else => {
            std.debug.print("Method not supported yet\n", .{});
            unreachable;
        },
    }
}
