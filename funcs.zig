const std = @import("std");
const stdout = std.io.getStdOut().writer();
const print = stdout.print;
const prompt = @import("prompt.zig");
const os = std.os;
const fmt = std.fmt;
const repo_status = @import("repo_status/repo_status.zig");

const C = prompt.C;

fn is_remote() bool {
    var tty = os.getenv("SSH_TTY");
    var client = os.getenv("SSH_CLIENT");
    return tty != null or client != null;
}

fn access(pth: []const u8, flags: std.fs.File.OpenFlags) !void {
    try std.fs.cwd().access(pth, flags);
}

fn fileExists(pth: []const u8) bool {
    access(pth, .{}) catch return false;
    return true;
}

fn is_writeable(pth: []const u8) bool {
    access(pth, .{ .write = true }) catch return false;
    return true;
}

fn is_docker() bool {
    return fileExists("/.dockerenv");
}

fn is_not_local() bool {
    return is_remote() or is_docker();
}

pub fn is_local() bool {
    return !is_not_local();
}

pub fn is_su() bool {
    var usr = os.getenv("USER") orelse "";
    var logname = os.getenv("LOGNAME") orelse "";
    return !std.mem.eql(u8, usr, logname);
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
    var p = os.getenv("PROMPT_PREFIX") orelse "";
    try print("{s}", .{p});
}

// report if the session is being recorded
pub fn script() !void {
    const E = prompt.E;
    if (os.getenv("SCRIPT")) |s| {
        try print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.white, E.c, s, E.o, C.reset, E.c });
    }
}

// tab - https://github.com/austinjones/tab-rs
pub fn tab() !void {
    const E = prompt.E;
    if (os.getenv("TAB")) |t| {
        try print("[{s}{s}{s}{s}{s}{s}{s}]", .{ E.o, C.green, E.c, t, E.o, C.reset, E.c });
    }
}

// screen/tmux status
pub fn screen() !void {
    const E = prompt.E;
    const term = os.getenv("TERM") orelse "";
    const tmux = os.getenv("TMUX") orelse "";
    var scr: []const u8 = undefined;
    var name: []const u8 = undefined;
    var window: []const u8 = undefined;

    if (!std.mem.eql(u8, term, "") and std.mem.eql(u8, term[0..6], "screen")) {
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
        try print("[{s}{s}{s}{s}{s}{s}{s}:{s}{s}{s}{s}{s}{s}{s}:{s}{s}{s}{s}{s}{s}{s}]", .{
            E.o, C.green,   E.c, scr,    E.o, C.reset, E.c,
            E.o, C.blue,    E.c, name,   E.o, C.reset, E.c,
            E.o, C.magenta, E.c, window, E.o, C.reset, E.c,
        });
    }
}

pub inline fn is_env_true(env_name: []const u8) bool {
    return parseZero(os.getenv(env_name)) != 0;
}

// virtual env
pub fn venv() !void {
    // example environment variable set in a venv:
    // VIRTUAL_ENV=/Users/kbd/.local/share/virtualenvs/pipenvtest-vxNzUMMM
    const E = prompt.E;
    if (os.getenv("VIRTUAL_ENV")) |v| {
        if (is_env_true("PROMPT_FULL_VENV")) {
            var name = std.fs.path.basename(v);
            try print("[{s}{s}{s}{s}{s}{s}{s}{s}]", .{ E.o, C.green, E.c, "🐍", name, E.o, C.reset, E.c });
        } else {
            try print("🐍", .{});
        }
    }
}

pub fn date() !void {} // eh, seems unnecessary bc iterm2 timestamps

pub fn user() !void {
    const E = prompt.E;
    var color: []const u8 = C.green;
    if (is_root()) {
        color = C.red;
    } else if (is_su()) {
        color = try fmt.allocPrint(prompt.A, "{s}{s}", .{ C.bold, C.yellow });
    }
    var u = os.getenv("USER");
    try print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, color, E.c, u, E.o, C.reset, E.c });
}

pub fn at() !void {
    const E = prompt.E;
    // show the @ in red if not local
    if (is_remote()) {
        try print("{s}{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.red, C.bold, E.c, "@", E.o, C.reset, E.c });
    } else {
        try print("@", .{});
    }
}

pub fn host() !void {
    const E = prompt.E;
    var buf: [os.HOST_NAME_MAX]u8 = undefined;
    _ = std.heap.FixedBufferAllocator.init(&buf);
    var h: []const u8 = try os.gethostname(&buf);
    if (!is_env_true("PROMPT_FULL_HOST")) {
        h = std.mem.split(h, ".").next().?;
    }
    try print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.blue, E.c, h, E.o, C.reset, E.c });
}

/// separator - C.red if cwd unwritable
pub fn sep() !void {
    try print(":", .{});
}

/// horizortal rule
pub fn hr() !void {
    var w: std.c.winsize = undefined;
    _ = std.c.ioctl(std.c.STDOUT_FILENO, std.c.TIOCGWINSZ, &w);
    var columns = w.ws_col;
    while (columns > 0) {
        try print("─", .{});
        columns -= 1;
    }
}

pub fn path() !void {
    const E = prompt.E;
    const cwd = prompt.CWD;

    var color = try fmt.allocPrint(prompt.A, "{s}{s}", .{ C.bright_magenta, C.bold });
    if (!is_writeable(cwd)) {
        color = try fmt.allocPrint(prompt.A, "{s}{s}", .{ color, C.underline });
    }

    const p = os.getenv("PROMPT_PATH") orelse cwd;
    try print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, color, E.c, p, E.o, C.reset, E.c });
}

// source control information
pub fn repo() !void {
    const E = prompt.E;
    const cwd = prompt.CWD;
    repo_status.A = prompt.A; // use my allocator

    if (!repo_status.isGitRepo(cwd))
        return;

    try print("[", .{});
    var status = try repo_status.getFullRepoStatus(cwd);
    // convert to repo_status's version of Escapes, unify in library later
    var escapes = repo_status.Escapes.init(E.o, E.c);
    try repo_status.writeStatusStr(escapes, status);
    try print("]", .{});
}

pub inline fn parseZero(val: ?[]const u8) u32 {
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
        j = try fmt.allocPrint(A, "{s}{s}{s}{}&{s}{s}{s}", .{ E.o, C.green, E.c, running, E.o, C.reset, E.c });
    }
    if (suspended > 0) {
        if (!std.mem.eql(u8, j, "")) {
            // separate running/suspended jobs with colon
            j = try fmt.allocPrint(A, "{s}:", .{j});
        }
        // 'z' for 'ctrl+z' to indicate "suspended"
        j = try fmt.allocPrint(A, "{s}{s}{s}{s}{}z{s}{s}{s}", .{ j, E.o, C.red, E.c, suspended, E.o, C.reset, E.c });
    }
    if (!std.mem.eql(u8, j, "")) {
        try print("[{s}]", .{j});
    }
}

pub fn direnv() !void {
    const E = prompt.E;
    if (os.getenv("DIRENV_DIR")) |d| {
        try print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.blue, E.c, "‡", E.o, C.reset, E.c });
    }
}

pub fn char() !void {
    const E = prompt.E;

    var code = parseZero(os.getenv("PROMPT_RETURN_CODE"));
    var c = if (is_root()) "#" else "$";
    if (code == 0) {
        try print("{s}{s}{s}{s}", .{ E.o, C.green, E.c, c });
    } else {
        try print("{s}{s}{s}{s}:{}", .{ E.o, C.red, E.c, c, code });
    }
    try print("{s}{s}{s} ", .{ E.o, C.reset, E.c });
}

pub fn newline_if(env_name: []const u8) !void {
    if (is_env_true(env_name)) {
        try print("\n", .{});
    }
}
