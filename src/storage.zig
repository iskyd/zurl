const std = @import("std");
const sqlite = @cImport(@cInclude("sqlite3.h"));

pub fn init(dbname: []const u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    const sql = "CREATE TABLE IF NOT EXISTS requests(id INT, name TEXT, method TEXT, url TEXT);";
    const res = sqlite.sqlite3_exec(db, sql, null, null, null);
    if (res == sqlite.SQLITE_OK) {
        std.debug.print("Query executed with success\n", .{});
    }
}

pub fn save(dbname: []const u8, reqname: []u8, method: []u8, url: []u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);
    _ = reqname;
    _ = method;
    _ = url;
}
