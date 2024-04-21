const std = @import("std");
// This must be public in order to be used by the test (refAllDecls(@This()))
pub const request = @import("src/request.zig");

test {
    std.testing.refAllDecls(@This());
}
