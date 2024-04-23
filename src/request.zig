const std = @import("std");
const curl = @cImport(@cInclude("curl/curl.h"));

const NULL: ?*anyopaque = null;

pub const HttpRequestMethod = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTIONS,
};

pub const QueryParam = struct { key: []const u8, value: []const u8 };
pub const Header = struct { key: []const u8, value: []const u8 };

pub const HttpRequest = struct {
    method: HttpRequestMethod,
    url: []const u8,
    headers: ?[]Header = null,
    params: ?[]QueryParam = null,
    json: ?[]u8 = null,

    pub fn getUrlWithQueryParamsCap(self: HttpRequest) usize {
        var cap: usize = self.url.len + 1; // add + 1 for null terminator
        if (self.params != null and self.params.?.len > 0) {
            cap += 1; // + 1 for ?
            for (self.params.?) |param| {
                cap += param.key.len;
                cap += param.value.len;
                cap += 1; // + 1 for =
            }
        }
        return cap;
    }

    pub fn getUrlWithQueryParams(self: HttpRequest, allocator: std.mem.Allocator) ![]u8 {
        const cap: usize = self.getUrlWithQueryParamsCap();
        var fullUrl: []u8 = try allocator.alloc(u8, cap);
        errdefer comptime unreachable; // From now on, no more errors
        std.mem.copy(u8, fullUrl[0..self.url.len], self.url);
        if (self.params != null and self.params.?.len > 0) {
            fullUrl[self.url.len] = '?';
            var cur: usize = self.url.len + 1;
            for (self.params.?) |param| {
                std.mem.copy(u8, fullUrl[cur..(cur + param.key.len)], param.key);
                fullUrl[cur + param.key.len] = '=';
                cur += param.key.len + 1;
                std.mem.copy(u8, fullUrl[cur..(cur + param.value.len)], param.value);
                cur += param.value.len;
            }
        }
        fullUrl[cap - 1] = 0; // Null terminator

        return fullUrl;
    }
};

pub fn execute(allocator: std.mem.Allocator, req: HttpRequest) !void {
    _ = curl.curl_global_init(curl.CURL_GLOBAL_DEFAULT);
    const fullUrl = try req.getUrlWithQueryParams(allocator);
    defer allocator.free(fullUrl);

    switch (req.method) {
        HttpRequestMethod.GET => {
            const handler = curl.curl_easy_init();
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, fullUrl.ptr);
            if (req.headers != null and req.headers.?.len > 0) {
                var headers: ?*curl.struct_curl_slist = null;
                for (req.headers.?) |h| {
                    const hstr = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ h.key, h.value });
                    defer allocator.free(hstr);

                    headers = curl.curl_slist_append(headers, hstr.ptr);
                }
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, headers);
            }

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
        HttpRequestMethod.POST => {
            const handler = curl.curl_easy_init();
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, fullUrl.ptr);
            if (req.headers != null and req.headers.?.len > 0) {
                var headers: ?*curl.struct_curl_slist = null;
                for (req.headers.?) |h| {
                    const hstr = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ h.key, h.value });
                    defer allocator.free(hstr);

                    headers = curl.curl_slist_append(headers, hstr.ptr);
                }
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, headers);
            }
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POST, @as(c_long, 1));
            if (req.json != null) {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, req.json.?.ptr);
            } else {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, "");
            }
            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
        },
        HttpRequestMethod.OPTIONS => {
            const handler = curl.curl_easy_init();
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, fullUrl.ptr);
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_CUSTOMREQUEST, "OPTIONS");
            if (req.headers != null and req.headers.?.len > 0) {
                var headers: ?*curl.struct_curl_slist = null;
                for (req.headers.?) |h| {
                    const hstr = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ h.key, h.value });
                    defer allocator.free(hstr);

                    headers = curl.curl_slist_append(headers, hstr.ptr);
                }
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, headers);
            }

            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
        },
        HttpRequestMethod.PUT => {
            const handler = curl.curl_easy_init();
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, fullUrl.ptr);
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_CUSTOMREQUEST, "PUT");
            if (req.headers != null and req.headers.?.len > 0) {
                var headers: ?*curl.struct_curl_slist = null;
                for (req.headers.?) |h| {
                    const hstr = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ h.key, h.value });
                    defer allocator.free(hstr);

                    headers = curl.curl_slist_append(headers, hstr.ptr);
                }
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, headers);
            }
            if (req.json != null) {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, req.json.?.ptr);
            } else {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, "");
            }

            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
        },
        HttpRequestMethod.PATCH => {
            const handler = curl.curl_easy_init();
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, fullUrl.ptr);
            _ = curl.curl_easy_setopt(handler, curl.CURLOPT_CUSTOMREQUEST, "PATCH");
            if (req.headers != null and req.headers.?.len > 0) {
                var headers: ?*curl.struct_curl_slist = null;
                for (req.headers.?) |h| {
                    const hstr = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ h.key, h.value });
                    defer allocator.free(hstr);

                    headers = curl.curl_slist_append(headers, hstr.ptr);
                }
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_HTTPHEADER, headers);
            }
            if (req.json != null) {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, req.json.?.ptr);
            } else {
                _ = curl.curl_easy_setopt(handler, curl.CURLOPT_POSTFIELDS, "");
            }

            const http_res = curl.curl_easy_perform(handler);
            _ = http_res;
            var status_code: c_long = 0;
            _ = curl.curl_easy_getinfo(handler, curl.CURLINFO_RESPONSE_CODE, &status_code);
            std.debug.print("Status Code: {}\n", .{status_code});
            _ = curl.curl_easy_cleanup(handler);
        },
    }
}

test "getUrlWithQueryParamsCap" {
    const req = HttpRequest{ .url = "https://github.com/iskyd/zurl", .method = HttpRequestMethod.GET };
    try std.testing.expectEqual(req.getUrlWithQueryParamsCap(), 30);
    var params: [1]QueryParam = [1]QueryParam{QueryParam{ .key = "key", .value = "value" }};
    const req2 = HttpRequest{ .url = "https://github.com/iskyd/zurl", .method = HttpRequestMethod.GET, .params = &params };
    try std.testing.expectEqual(req2.getUrlWithQueryParamsCap(), 40);
}

test "getUrlWithQueryParams" {
    const allocator = std.testing.allocator;
    const req = HttpRequest{ .url = "https://github.com/iskyd/zurl", .method = HttpRequestMethod.GET };
    const fullUrl = try req.getUrlWithQueryParams(allocator);
    defer allocator.free(fullUrl);
    try std.testing.expectEqualStrings("https://github.com/iskyd/zurl\x00", fullUrl);

    var params: [1]QueryParam = [1]QueryParam{QueryParam{ .key = "key", .value = "value" }};
    const req2 = HttpRequest{ .url = "https://github.com/iskyd/zurl", .method = HttpRequestMethod.GET, .params = &params };
    const fullUrl2 = try req2.getUrlWithQueryParams(allocator);
    defer allocator.free(fullUrl2);
    try std.testing.expectEqualStrings("https://github.com/iskyd/zurl?key=value\x00", fullUrl2);
}
