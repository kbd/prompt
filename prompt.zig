const std = @import("std");
const stdout = std.io.getStdOut().writer();
const print = stdout.print;
const os = std.os;
const Allocator = std.mem.Allocator;
const funcs = @import("funcs.zig");

pub const Escapes = struct {
    o: [:0]const u8 = undefined,
    c: [:0]const u8 = undefined,

    pub fn init(open: [:0]const u8, close: [:0]const u8) Escapes {
        return Escapes{ .o = open, .c = close };
    }
};

pub const C = .{
    .reset = "\x1b[00m",
    .bold = "\x1b[01m",
    .italic = "\x1b[03m",
    .underline = "\x1b[04m",
    .reverse = "\x1b[07m",
    .italic_off = "\x1b[23m",
    .underline_off = "\x1b[24m",
    .reverse_off = "\x1b[27m",
    .default = "\x1b[91m",

    .black = "\x1b[30m",
    .red = "\x1b[31m",
    .green = "\x1b[32m",
    .yellow = "\x1b[33m",
    .blue = "\x1b[34m",
    .magenta = "\x1b[35m",
    .cyan = "\x1b[36m",
    .white = "\x1b[37m",
};

pub var A: *Allocator = undefined; // allocator
pub var E: Escapes = undefined; // escapes
pub var CWD: []u8 = undefined; // colors
pub var RUNNING: u16 = undefined;
pub var SUSPENDED: u16 = undefined;

// command line arguments need to be:
// 1. last return code
// 2. running/suspended jobs
// 3. custom path (support zsh hashed directories)
// colors - https://en.wikipedia.org/wiki/ANSI_escape_code

// # configuration variables exposed:
// #
// # $PROMPT_FULL_HOST
// #   shows the full hostname (\H vs \h in ps1)
// #
// # $PROMPT_SHORT_DISPLAY
// #   don't display things like username@host if you're the main user on localhost
// #   and the date if you have iTerm's timestamp on. i.e. elide unnecessary info.
// #   "use short display" implies "hide date"
// #
// # $PROMPT_PREFIX
// #   override to control what's displayed at the start of the prompt line
// #
// # $PROMPT_BARE
// #   set to enable a very minimal prompt, useful for copying exmaples
// #
// # note: this code depends on colors.sh and on 'filter' program in path
// _prompt_date() {
//   echo -n "$eo${COL[grey]}$ec$dt$eo${COL[reset]}$ec:"
// }

fn dummy() !void {}

fn filter(prompt_funcs: *std.StringHashMap(*const @TypeOf(dummy))) void {
    var bare = os.getenv("PROMPT_BARE") orelse "";
    if (!std.mem.eql(u8, bare, "")) {
        // only show 'char' for bare prompt
        var it = prompt_funcs.iterator();
        while (it.next()) |pair| {
            if (!std.mem.eql(u8, pair.key, "char")) {
                _ = prompt_funcs.remove(pair.key);
            }
        }
    }

    const short_display = os.getenv("PROMPT_SHORT_DISPLAY") orelse "";
    if (!std.mem.eql(u8, short_display, "")) {
        // showing the host (and user, if not su/root) is unnecessary if local
        if (funcs.is_local()) {
            _ = prompt_funcs.remove("at");
            _ = prompt_funcs.remove("host");
        }
        if (!funcs.is_su() and !funcs.is_root()) {
            _ = prompt_funcs.remove("user");
        }

        // if no user or host, remove sep too
        if (!prompt_funcs.contains("user") and !prompt_funcs.contains("host")) {
            _ = prompt_funcs.remove("sep");
        }
    }
}

pub fn main() !void {
    // allocator setup
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    A = &arena.allocator;

    // escapes
    if (std.os.isatty(1)) {
        E = Escapes.init("", ""); // interactive
    } else {
        E = Escapes.init("%{", "%}"); // zsh
    }

    // state
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    CWD = try std.os.getcwd(&buf);

    // functions
    var funcmap = std.StringHashMap(*const @TypeOf(dummy)).init(A);
    defer funcmap.deinit();

    try funcs.prefix();
    try funcs.script();
    try funcs.tab();
    try funcs.screen();
    try funcs.venv();
    try funcs.date();
    try funcs.user();
    try funcs.at();
    try funcs.host();
    try funcs.sep();
    try funcs.path();
    try funcs.repo();
    try funcs.jobs();
    try funcs.direnv();
    try funcs.char();

    // const fs = .{
    //     "prefix", "script", "tab",  "screen", "venv", "date",   "user", "at",
    //     "host",   "sep",    "path", "repo",   "jobs", "direnv", "char",
    // };
    // inline for (fs) |f| {
    //     try funcmap.putNoClobber(f, &@field(funcs, f));
    // }
    // filter(&funcmap);
    // inline for (fs) |f| {
    //     if (funcmap.get(f)) |func| {
    //         // https://github.com/ziglang/zig/issues/4639
    //         try @call(.{}, func.*, .{});
    //     }
    // }
}
