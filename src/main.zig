const std = @import("std");
const curl = @cImport(@cInclude("curl/curl.h"));
const clap = @import("clap");

pub fn main() !void {
    std.debug.print("Zurl. Curl wrapper for json requests.\n", .{});

    _ = curl.curl_global_init(curl.CURL_GLOBAL_DEFAULT);
    const handler = curl.curl_easy_init();
    _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, "https://www.google.com");
    const res = curl.curl_easy_perform(handler);
    if (res != curl.CURLE_OK) {
        std.debug.print("Error while executing request", .{});
    } else {
        std.debug.print("Request executed", .{});
    }
    _ = curl.curl_easy_cleanup(handler);
}
