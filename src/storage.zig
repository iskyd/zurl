const std = @import("std");
const sqlite = @cImport(@cInclude("sqlite3.h"));

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

pub fn save(dbname: []const u8, reqname: []const u8, method: []const u8, url: []const u8) !void {
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

    rc = sqlite.sqlite3_bind_text(stmt, 3, method.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 4, url.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_DONE) {
        return error.Step;
    }

    _ = sqlite.sqlite3_finalize(stmt);
    if (rc != sqlite.SQLITE_DONE) {
        return error.Finalize;
    }

    _ = sqlite.sqlite3_close(db);
}

pub fn get(dbname: []const u8, reqname: []u8) void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);
    _ = reqname;
}

pub fn list(dbname: []const u8) void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);
}
