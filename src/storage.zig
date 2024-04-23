const std = @import("std");
const sqlite = @cImport(@cInclude("sqlite3.h"));
const request = @import("request.zig");

const DB_LIST_SEPARATOR = "|||";

pub fn init(dbname: []const u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    const sql = "CREATE TABLE IF NOT EXISTS requests(id INTEGER PRIMARY KEY, name TEXT UNIQUE, method TEXT, url TEXT, param TEXT, headers TEXT);";
    const res = sqlite.sqlite3_exec(db, sql, null, null, null);
    if (res == sqlite.SQLITE_OK) {
        std.debug.print("Query executed with success\n", .{});
    } else {
        return error.InitDBError;
    }

    _ = sqlite.sqlite3_close(db);
}

fn strListSeparatedCap(dbrepr: []const u8) usize {
    var cap: usize = 0;
    var it = std.mem.split(u8, dbrepr, DB_LIST_SEPARATOR);
    while (it.next()) |_| {
        cap += 1;
    }
    return cap;
}

fn paramsToDB(allocator: std.mem.Allocator, params: []request.QueryParam) ![]u8 {
    var cap: usize = 0;
    for (params) |p| {
        cap += p.key.len + p.value.len + 5; // 5 -> key=value|||\x00 (=,|||,null terminator)

    }
    cap -= 3; // Remove 3 trailing |||
    var repr: []u8 = try allocator.alloc(u8, cap);
    var cur: usize = 0;
    for (params) |p| {
        std.mem.copy(u8, repr[cur .. cur + p.key.len], p.key);
        repr[cur + p.key.len] = '=';
        cur += p.key.len + 1;
        std.mem.copy(u8, repr[cur .. cur + p.value.len], p.value);
        cur += p.value.len;
        if (cur + 3 < cap) {
            std.mem.copy(u8, repr[cur .. cur + 3], DB_LIST_SEPARATOR);
            cur += 3;
        }
    }
    repr[cap - 1] = 0;

    return repr;
}

fn paramsFromDB(allocator: std.mem.Allocator, dbrepr: []const u8) !?[]request.QueryParam {
    const cap: usize = strListSeparatedCap(dbrepr);
    if (cap == 0) {
        return null;
    }
    var params: []request.QueryParam = try allocator.alloc(request.QueryParam, cap);
    var it = std.mem.split(u8, dbrepr, "|||");
    var cur: usize = 0;
    while (it.next()) |p| {
        var it2 = std.mem.split(u8, p, "=");
        const k = it2.next().?;
        const v = it2.next().?;
        var key = try allocator.alloc(u8, k.len);
        var value = try allocator.alloc(u8, v.len);
        std.mem.copy(u8, key, k);
        std.mem.copy(u8, value, v);
        params[cur] = request.QueryParam{ .key = key, .value = value };
        cur += 1;
    }
    return params;
}

fn headersToDB(allocator: std.mem.Allocator, headers: []request.Header) ![]u8 {
    var cap: usize = 0;
    for (headers) |h| {
        cap += h.key.len + h.value.len + 5; // 5 -> key=value|||\x00 (=,|||,null terminator)

    }
    cap -= 3; // Remove 3 trailing |||
    var repr: []u8 = try allocator.alloc(u8, cap);
    var cur: usize = 0;
    for (headers) |h| {
        std.mem.copy(u8, repr[cur .. cur + h.key.len], h.key);
        repr[cur + h.key.len] = '=';
        cur += h.key.len + 1;
        std.mem.copy(u8, repr[cur .. cur + h.value.len], h.value);
        cur += h.value.len;
        if (cur + 3 < cap) {
            std.mem.copy(u8, repr[cur .. cur + 3], DB_LIST_SEPARATOR);
            cur += 3;
        }
    }
    repr[cap - 1] = 0;

    return repr;
}

fn headersFromDB(allocator: std.mem.Allocator, dbrepr: []const u8) !?[]request.Header {
    const cap: usize = strListSeparatedCap(dbrepr);
    if (cap == 0) {
        return null;
    }
    var headers: []request.Header = try allocator.alloc(request.Header, cap);
    var it = std.mem.split(u8, dbrepr, "|||");
    var cur: usize = 0;
    while (it.next()) |p| {
        var it2 = std.mem.split(u8, p, "=");
        const k = it2.next().?;
        const v = it2.next().?;
        var key = try allocator.alloc(u8, k.len);
        var value = try allocator.alloc(u8, v.len);
        std.mem.copy(u8, key, k);
        std.mem.copy(u8, value, v);
        headers[cur] = request.Header{ .key = key, .value = value };
        cur += 1;
    }
    return headers;
}

pub fn save(allocator: std.mem.Allocator, dbname: []const u8, name: []const u8, req: request.HttpRequest) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "INSERT INTO requests(id, name, method, url, params, headers) VALUES(?, ?, ?, ?, ?, ?)";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    rc = sqlite.sqlite3_bind_null(stmt, 1);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 2, name.ptr, -1, sqlite.SQLITE_TRANSIENT);
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

    if (req.params == null or req.params.?.len == 0) {
        rc = sqlite.sqlite3_bind_null(stmt, 5);
        if (rc != sqlite.SQLITE_OK) {
            return error.BindText;
        }
    } else {
        const dbrepr = try paramsToDB(allocator, req.params.?);
        defer allocator.free(dbrepr);
        rc = sqlite.sqlite3_bind_text(stmt, 5, dbrepr.ptr, -1, sqlite.SQLITE_TRANSIENT);
        if (rc != sqlite.SQLITE_OK) {
            return error.BindText;
        }
    }

    if (req.headers == null or req.headers.?.len == 0) {
        rc = sqlite.sqlite3_bind_null(stmt, 6);
        if (rc != sqlite.SQLITE_OK) {
            return error.BindText;
        }
    } else {
        const dbrepr = try headersToDB(allocator, req.headers.?);
        defer allocator.free(dbrepr);
        rc = sqlite.sqlite3_bind_text(stmt, 6, dbrepr.ptr, -1, sqlite.SQLITE_TRANSIENT);
        if (rc != sqlite.SQLITE_OK) {
            return error.BindText;
        }
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_DONE) {
        return error.Step;
    }

    _ = sqlite.sqlite3_finalize(stmt);
    _ = sqlite.sqlite3_close(db);
}

pub fn get(allocator: std.mem.Allocator, dbname: []const u8, name: []const u8) !request.HttpRequest {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "SELECT url, method, params, headers FROM requests WHERE name=?";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 1, name.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_ROW) {
        return error.NotFound;
    }

    const urlsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 0));
    const urlptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 0)))[0..urlsize];
    var url: []u8 = try allocator.alloc(u8, urlptr.len);
    std.mem.copy(u8, url[0..], urlptr[0..]);
    const methodsize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 1));
    const methodptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 1)))[0..methodsize];
    const method: request.HttpRequestMethod = std.meta.stringToEnum(request.HttpRequestMethod, methodptr).?;

    const paramssize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 2));
    const paramsptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 2)))[0..paramssize];
    const params: ?[]request.QueryParam = try paramsFromDB(allocator, paramsptr);

    const headerssize: usize = @intCast(sqlite.sqlite3_column_bytes(stmt, 3));
    const headersptr = @as([*c]const u8, @ptrCast(sqlite.sqlite3_column_text(stmt, 3)))[0..headerssize];
    const headers: ?[]request.Header = try headersFromDB(allocator, headersptr);

    _ = sqlite.sqlite3_finalize(stmt);
    _ = sqlite.sqlite3_close(db);

    return request.HttpRequest{ .url = url, .method = method, .params = params, .headers = headers };
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

pub fn delete(dbname: []const u8, name: []const u8) !void {
    var db: ?*sqlite.sqlite3 = undefined;
    _ = sqlite.sqlite3_open(dbname.ptr, &db);

    var stmt: ?*sqlite.sqlite3_stmt = undefined;
    const sql = "DELETE FROM requests WHERE name=?";

    var rc: c_int = 0;

    rc = sqlite.sqlite3_prepare_v2(db, sql, -1, &stmt, 0);
    if (rc != sqlite.SQLITE_OK) {
        return error.PrepareStmt;
    }

    rc = sqlite.sqlite3_bind_text(stmt, 1, name.ptr, -1, sqlite.SQLITE_TRANSIENT);
    if (rc != sqlite.SQLITE_OK) {
        return error.BindText;
    }

    rc = sqlite.sqlite3_step(stmt);
    if (rc != sqlite.SQLITE_DONE) {
        return error.Step;
    }
}
