const std = @import("std");
const stdout = std.io.getStdOut().writer();
const prompt = @import("prompt.zig");
const os = std.posix;
const fmt = std.fmt;
const repo_status = @import("repo_status/repo_status.zig");

const C = prompt.C;

fn is_remote() bool {
    const tty = os.getenv("SSH_TTY");
    const client = os.getenv("SSH_CLIENT");
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
    access(pth, .{ .mode = .write_only }) catch return false;
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
    const usr = os.getenv("USER") orelse "";
    const logname = os.getenv("LOGNAME") orelse "";
    return !std.mem.eql(u8, usr, logname);
}

pub fn is_root() bool {
    const euid_str = os.getenv("EUID") orelse "1000";
    const euid = fmt.parseInt(u32, euid_str, 10) catch 1000;
    return euid == 0;
}

fn run(argv: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = prompt.A,
        .argv = argv,
    });
    return std.mem.trim(u8, result.stdout, " \n");
}

pub fn prefix() !void {
    const p = os.getenv("PROMPT_PREFIX") orelse "";
    try stdout.print("{s}", .{p});
}

// report if the session is being recorded
pub fn script() !void {
    const E = prompt.E;
    if (os.getenv("SCRIPT")) |s| {
        try stdout.print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.white, E.c, s, E.o, C.reset, E.c });
    }
}

// tab - https://github.com/austinjones/tab-rs
pub fn tab() !void {
    const E = prompt.E;
    if (os.getenv("TAB")) |t| {
        try stdout.print("[{s}{s}{s}{s}{s}{s}{s}]", .{ E.o, C.green, E.c, t, E.o, C.reset, E.c });
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
        try stdout.print("[{s}{s}{s}{s}{s}{s}{s}:{s}{s}{s}{s}{s}{s}{s}:{s}{s}{s}{s}{s}{s}{s}]", .{
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
            const name = std.fs.path.basename(v);
            try stdout.print("[{s}{s}{s}{s}{s}{s}{s}{s}]", .{ E.o, C.green, E.c, "🐍", name, E.o, C.reset, E.c });
        } else {
            try stdout.print("🐍", .{});
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
    const u = os.getenv("USER") orelse "";
    try stdout.print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, color, E.c, u, E.o, C.reset, E.c });
}

pub fn at() !void {
    const E = prompt.E;
    // show the @ in red if not local
    if (is_remote()) {
        try stdout.print("{s}{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.red, C.bold, E.c, "@", E.o, C.reset, E.c });
    } else {
        try stdout.print("@", .{});
    }
}

pub fn host() !void {
    const E = prompt.E;
    var buf: [os.HOST_NAME_MAX]u8 = undefined;
    _ = std.heap.FixedBufferAllocator.init(&buf);
    var h: []const u8 = try os.gethostname(&buf);
    if (!is_env_true("PROMPT_FULL_HOST")) {
        var iter = std.mem.split(u8, h, ".");
        h = iter.first();
    }
    try stdout.print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, C.blue, E.c, h, E.o, C.reset, E.c });
}

/// separator - C.red if cwd unwritable
pub fn sep() !void {
    try stdout.print(":", .{});
}

/// horizortal rule
pub fn hr() !void {
    var columns = parseZero(os.getenv("PROMPT_HR"));
    if (columns > 0) {
        const E = prompt.E;
        try stdout.print("{s}{s}{s}", .{ E.o, C.bright_black, E.c });
        defer stdout.print("{s}{s}{s}", .{ E.o, C.reset, E.c }) catch {};
        while (columns > 0) {
            try stdout.print("─", .{});
            columns -= 1;
        }
        // zsh is smart and will not put an extra line if your line ends in newline
        // this will maintain formatting when terminal is resized
        try stdout.print("\n", .{});
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
    try stdout.print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, color, E.c, p, E.o, C.reset, E.c });
}

// source control information
pub fn repo() !void {
    const E = prompt.E;
    const cwd = prompt.CWD;
    repo_status.A = prompt.A; // use my allocator

    if (!repo_status.isGitRepo(cwd))
        return;

    try stdout.print("[", .{});
    const status = try repo_status.getFullRepoStatus(cwd);
    // convert to repo_status's version of Escapes, unify in library later
    const escapes = repo_status.Escapes.init(E.o, E.c);
    try repo_status.writeStatusStr(escapes, status);
    try stdout.print("]", .{});
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
    var iter = std.mem.split(u8, prompt_jobs, " ");
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
        try stdout.print("[{s}]", .{j});
    }
}

pub fn direnv() !void {
    const E = prompt.E;
    const file = os.getenv("DIRENV_FILE") orelse return; // return if not in direnv
    const dir = std.fs.path.dirname(file) orelse return;
    const cwd = prompt.CWD;
    var color = C.blue;
    if (std.mem.eql(u8, dir, cwd)) { // if direnv in current directory, show in green
        color = C.green;
    }
    try stdout.print("{s}{s}{s}{s}{s}{s}{s}", .{ E.o, color, E.c, "‡", E.o, C.reset, E.c });
}

pub fn char() !void {
    const E = prompt.E;

    const code = parseZero(os.getenv("PROMPT_RETURN_CODE"));
    const c = if (is_root()) "#" else "$";
    if (code == 0) {
        try stdout.print("{s}{s}{s}{s}", .{ E.o, C.green, E.c, c });
    } else {
        try stdout.print("{s}{s}{s}{s}:{}", .{ E.o, C.red, E.c, c, code });
    }
    try stdout.print("{s}{s}{s} ", .{ E.o, C.reset, E.c });
}

pub fn newline_if(env_name: []const u8) !void {
    if (is_env_true(env_name)) {
        try stdout.print("\n", .{});
    }
}

pub fn formatArg(arg: []const u8, value: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(prompt.A, "{s}={s}", .{ arg, value });
}

pub fn set_kitty_tab_color() !void {
    // run kitty asynchronously and don't wait for result
    const term = os.getenv("TERM") orelse "";
    const listen = os.getenv("KITTY_LISTEN_ON") orelse "";
    if (!std.mem.eql(u8, term, "xterm-kitty") or std.mem.eql(u8, listen, "")) {
        return;
    }

    const afg = os.getenv("KITTY_TAB_AFG") orelse "NONE";
    const abg = os.getenv("KITTY_TAB_ABG") orelse "NONE";
    const ifg = os.getenv("KITTY_TAB_IFG") orelse "NONE";
    const ibg = os.getenv("KITTY_TAB_IBG") orelse "NONE";

    // zig fmt: off
    const cmd = [_][]const u8{
        "kitty", "@", "set-tab-color", "--self",
        try formatArg("active_fg", afg),
        try formatArg("active_bg", abg),
        try formatArg("inactive_fg", ifg),
        try formatArg("inactive_bg", ibg),
    };
    // zig fmt: on

    var child = std.process.Child.init(&cmd, prompt.A);
    return child.spawn();
}
