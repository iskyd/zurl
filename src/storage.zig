const std = @import("std");
const sqlite = @cImport(@cInclude("sqlite3.h"));
const request = @import("request.zig");

pub fn init(dbname: []const u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    const sql = "CREATE TABLE IF NOT EXISTS requests(id INTEGER PRIMARY KEY, name TEXT, method TEXT, url TEXT);";
    const res = sqlite.sqlite3_exec(db, sql, null, null, null);
    if (res == sqlite.SQLITE_OK) {
        std.debug.print("Query executed with success\n", .{});
    } else {
        return error.InitDBError;
    }

    _ = sqlite.sqlite3_close(db);
}

pub fn save(dbname: []const u8, reqname: []const u8, req: request.HttpRequest) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "INSERT INTO requests(id, name, method, url) VALUES(?, ?, ?, ?)";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    rc = sqlite.sqlite3_bind_null(stmt, 1);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 2, reqname.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 3, @tagName(req.method), -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 4, req.url.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_DONE) {
        return error.Step;
    }

    _ = sqlite.sqlite3_finalize(stmt);
    _ = sqlite.sqlite3_close(db);
}

pub fn get(allocator: std.mem.Allocator, dbname: []const u8, reqname: []const u8) !?request.HttpRequest {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "SELECT url, method FROM requests WHERE name=?";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 1, reqname.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_ROW) {
        return error.NotFound;
    }

    const urlsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 0));
    const urlptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 0)))[0..urlsize];
    const methodsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 1));
    const methodptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 1)))[0..methodsize];
    const method: request.HttpRequestMethod = std.meta.stringToEnum(request.HttpRequestMethod, methodptr).?;

    _ = sqlite.sqlite3_finalize(stmt);
    _ = sqlite.sqlite3_close(db);

    return request.HttpRequest{ .url = try allocator.dupe(u8, urlptr), .method = method };
}

pub fn list(dbname: []const u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "SELECT name, url, method FROM requests";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    while (true) {
        const row = sqlite.sqlite3_step(stmt);
        if (row != sqlite.SQLITE_ROW) {
            return;
        }

        const namesize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 0));
        const nameptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 1)))[0..namesize];
        const urlsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 1));
        const urlptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 1)))[0..urlsize];
        const methodsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 2));
        const methodptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 2)))[0..methodsize];

        std.debug.print("Name: {s}, Url: {s}, Method: {s}\n", .{ nameptr, urlptr, methodptr });
    }

    _ = sqlite.sqlite3_finalize(stmt);
    _ = sqlite.sqlite3_close(db);
}
