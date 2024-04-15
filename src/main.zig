const std = @import("std");
const curl = @cImport(@cInclude("curl/curl.h"));

fn checkGrade(grade: u32) !u8 {
    return switch (grade) {
        90...100 => 'A',
        80...89 => 'B',
        70...79 => 'C',
        60...69 => 'D',
        0...59 => 'F',
        else => error.InvalidGrade,
    };
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const grade: u32 = 90;
    const resultGrade = try checkGrade(grade);
    std.debug.print("grade {c}", .{resultGrade});

    _ = curl.curl_global_init(curl.CURL_GLOBAL_DEFAULT);
    const handler = curl.curl_easy_init();
    _ = curl.curl_easy_setopt(handler, curl.CURLOPT_URL, "http://google.com");
    const res = curl.curl_easy_perform(handler);
    if (res != curl.CURLE_OK) {
        std.debug.print("Error while executing request", .{});
    } else {
        std.debug.print("Request executed", .{});
    }
    _ = curl.curl_easy_cleanup(handler);

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
