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

pub var A: *Allocator = undefined;
pub var E: Escapes = undefined;
pub var CWD: []u8 = undefined;

//!  Configurable environment variables:
//!
//!  $PROMPT_PREFIX - default ⚡
//!    override to control what's displayed at the start of the prompt line
//!
//!  $PROMPT_BARE
//!    set to enable a very minimal prompt
//!
//!  $PROMPT_FULL_HOST
//!    shows the full hostname (bash: \H \h -- zsh: %M %m)
//!
//!  $PROMPT_LONG
//!    display username@host even if local
//!
//!  $PROMPT_PATH
//!    set to use things like Zsh's hashed paths
//!    export PROMPT_PATH="$(print -P '%~')"
//!
//!  $PROMPT_RETURN_CODE
//!    set to display the exit code of the previous program
//!    export PROMPT_RETURN_CODE=$?
//!
//!  $PROMPT_JOBS
//!    set to "{running} {suspended}" jobs (separated by space, defaults to 0 0)
//!    for zsh: (https://unix.stackexchange.com/a/68635)
//!    export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running} ${(M)#${jobstates%%:*}:#suspended}

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
    const long = funcs.parseZero(os.getenv("PROMPT_LONG")) != 0;

    // print prompt
    if (funcs.parseZero(os.getenv("PROMPT_BARE")) == 0) {
        try funcs.prefix();
        try funcs.script();
        try funcs.tab();
        try funcs.screen();
        try funcs.venv();
        try funcs.date();

        var show_sep = false;

        // showing the host (and user, if not su/root) is unnecessary if local
        if (funcs.is_root() or funcs.is_su() or long) {
            show_sep = true;
            try funcs.user();
        }

        if (!funcs.is_local() or long) {
            show_sep = true;
            try funcs.at();
            try funcs.host();
        }

        // if no user or host, remove sep too
        if (show_sep) {
            try funcs.sep();
        }

        try funcs.path();
        try funcs.repo();
        try funcs.jobs();
        try funcs.direnv();
    }
    try funcs.char();
}
