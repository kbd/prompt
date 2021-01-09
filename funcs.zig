const std = @import("std");
const stdout = std.io.getStdOut().writer();
const print = stdout.print;
const prompt = @import("prompt.zig");
const os = std.os;
const fmt = std.fmt;

const C = prompt.C;

fn is_remote() bool {
    var tty = os.getenv("SSH_TTY");
    var client = os.getenv("SSH_CLIENT");
    return tty != null or client != null;
}

fn is_docker() bool {
    return false; // [[ -f '/.dockerenv' ]];
}

fn is_not_local() bool {
    return is_remote() or is_docker();
}

pub fn is_local() bool {
    return !is_not_local();
}

pub fn is_su() bool {
    return !std.mem.eql(u8, os.getenv("USER").?, os.getenv("LOGNAME").?);
}

pub fn is_root() bool {
    var euid_str = os.getenv("EUID") orelse "1000";
    var euid = fmt.parseInt(u32, euid_str, 10) catch 1000;
    return euid == 0;
}

fn run(argv: []const []const u8) ![]const u8 {
    const result = try std.ChildProcess.exec(.{
        .allocator = prompt.A,
        .argv = argv,
    });
    return std.mem.trim(u8, result.stdout, " \n");
}

pub fn prefix() !void {
    var p = os.getenv("PROMPT_PREFIX") orelse "⚡";
    try print("{}", .{p});
}

pub fn script() !void {
    const E = prompt.E;

    // report if the session is being recorded
    var s = os.getenv("SCRIPT") orelse "";
    if (!std.mem.eql(u8, s, "")) {
        try print("{}{}{}{}{}{}{}", .{ E.o, C.white, E.c, s, E.o, C.reset, E.c });
    }
}

// # tab - https://github.com/austinjones/tab-rs
pub fn tab() !void {
    const E = prompt.E;

    var t = os.getenv("TAB") orelse "";
    if (!std.mem.eql(u8, t, "")) {
        try print("[{}{}{}{}{}{}{}]", .{ E.o, C.green, E.c, t, E.o, C.reset, E.c });
    }
}

// # screen/tmux status in prompt
pub fn screen() !void {
    const E = prompt.E;
    const term = os.getenv("TERM") orelse "";
    const tmux = os.getenv("TMUX") orelse "";
    var scr: []const u8 = undefined;
    var name: []const u8 = undefined;
    var window: []const u8 = undefined;

    if (std.mem.eql(u8, term[0..6], "screen")) {
        // figure out whether 'screen' or 'tmux'
        if (!std.mem.eql(u8, tmux, "")) {
            scr = "tmux";
            name = try run(&[_][]const u8{ "tmux", "display-message", "-p", "#S" });
            window = try run(&[_][]const u8{ "tmux", "display-message", "-p", "#I" });
        } else { // screen
            scr = "screen";
            name = os.getenv("STY") orelse "";
            window = os.getenv("WINDOW") orelse "";
        }
        try print("[{}{}{}{}{}{}{}:{}{}{}{}{}{}{}:{}{}{}{}{}{}{}]", .{
            E.o, C.green,   E.c, scr,    E.o, C.reset, E.c,
            E.o, C.blue,    E.c, name,   E.o, C.reset, E.c,
            E.o, C.magenta, E.c, window, E.o, C.reset, E.c,
        });
    }
}

// virtual env
pub fn venv() !void {
    // example environment variable set in a venv:
    // VIRTUAL_ENV=/Users/kbd/.local/share/virtualenvs/pipenvtest-vxNzUMMM
    const E = prompt.E;
    var v = os.getenv("VIRTUAL_ENV") orelse "";
    if (!std.mem.eql(u8, v, "")) {
        var name = std.fs.path.basename(v);
        try print("[{}{}{}{}{}{}{}{}]", .{ E.o, C.green, E.c, "🐍", name, E.o, C.reset, E.c });
    }
}

pub fn date() !void {} // eh, seems unnecessary bc iterm2 timestamps

pub fn user() !void {
    const E = prompt.E;
    var color: []const u8 = C.green;
    if (is_root()) {
        color = C.red;
    } else if (is_su()) {
        color = try fmt.allocPrint(prompt.A, "{}{}", .{ C.bold, C.yellow });
    }
    var u = os.getenv("USER");
    try print("{}{}{}{}{}{}{}", .{ E.o, color, E.c, u, E.o, C.reset, E.c });
}

pub fn at() !void {
    const E = prompt.E;
    // show the @ in red if not local
    if (is_remote()) {
        try print("{}{}{}{}{}{}{}{}", .{ E.o, C.red, C.bold, E.c, "@", E.o, C.reset, E.c });
    } else {
        try print("@", .{});
    }
}

pub fn host() !void {
    const E = prompt.E;

    const show_full_host = parseZero(os.getenv("PROMPT_FULL_HOST")) != 0;
    var buf: [os.HOST_NAME_MAX]u8 = undefined;
    _ = std.heap.FixedBufferAllocator.init(&buf);
    var h: []const u8 = try os.gethostname(&buf);
    if (!show_full_host) {
        h = std.mem.split(h, ".").next().?;
    }
    try print("{}{}{}{}{}{}{}", .{ E.o, C.blue, E.c, h, E.o, C.reset, E.c });
}

pub fn sep() !void {
    // separator - C.red if cwd unwritable
    var s = ":";
    //   if [[ ! -w "${PWD}" ]]; then
    //     s="$eo${COL[C.red]}${COL[bold]}$ec$s$eo${COL[C.reset]}$ec"
    //   fi
    try print("{}", .{s});
}

pub fn path() !void {
    const E = prompt.E;
    const p = os.getenv("PROMPT_PATH") orelse prompt.CWD;

    try print("{}{}{}{}{}{}{}{}", .{ E.o, C.bold, C.magenta, E.c, p, E.o, C.reset, E.c });
}

// source control information in prompt
pub fn repo() !void {
    // try to run repo_status and get its output. If it can't be run, show nothing.
    const repostr = try run(&[_][]const u8{"repo_status"});
    if (!std.mem.eql(u8, repostr, "")) {
        try print("[{}]", .{repostr});
    }
}

inline fn parseZero(val: ?[]const u8) u32 {
    // get an int value out of the string, one way or another, defaulting to 0
    return fmt.parseInt(u32, val orelse "0", 10) catch 0;
}

// running and stopped jobs
pub fn jobs() !void {
    const A = prompt.A;
    const E = prompt.E;

    const prompt_jobs = os.getenv("PROMPT_JOBS") orelse "0 0";
    var iter = std.mem.split(prompt_jobs, " ");
    const running = parseZero(iter.next());
    const suspended = parseZero(iter.next());

    var j: []u8 = "";
    if (running > 0) {
        // '&'' for "background"
        j = try fmt.allocPrint(A, "{}{}{}{}&{}{}{}", .{ E.o, C.green, E.c, running, E.o, C.reset, E.c });
    }
    if (suspended > 0) {
        if (!std.mem.eql(u8, j, "")) {
            // separate running/suspended jobs with colon
            j = try fmt.allocPrint(A, "{}:", .{j});
        }
        // 'z' for 'ctrl+z' to indicate "suspended"
        j = try fmt.allocPrint(A, "{}{}{}{}{}z{}{}{}", .{ j, E.o, C.red, E.c, suspended, E.o, C.reset, E.c });
    }
    if (!std.mem.eql(u8, j, "")) {
        try print("[{}]", .{j});
    }
}

pub fn direnv() !void {
    const E = prompt.E;

    var d = os.getenv("DIRENV_DIR");
    if (d != null) {
        try print("{}{}{}{}{}{}{}", .{ E.o, C.blue, E.c, "‡", E.o, C.reset, E.c });
    }
}

pub fn char() !void {
    const E = prompt.E;

    var code = parseZero(os.getenv("PROMPT_RETURN_CODE"));
    var c = if (is_root()) "#" else "$";
    if (code == 0) {
        try print("{}{}{}{}", .{ E.o, C.green, E.c, c });
    } else {
        try print("{}{}{}{}:{}", .{ E.o, C.red, E.c, c, code });
    }
    try print("{}{}{} ", .{ E.o, C.reset, E.c });
}
