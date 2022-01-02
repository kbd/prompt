//!  Configurable environment variables:
//!
//!  $PROMPT_PREFIX
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
//!    export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}
//!
//!  $PROMPT_FULL_VENV
//!    set to show the full name of virtualenvs vs an indicator
//!
//!  $PROMPT_LINE_BEFORE, $PROMPT_LINE_AFTER
//!    set for a multiline prompt. if set, add newline before/after each prompt
//!
//!  $PROMPT_HR
//!    set to $COLUMNS to print a horizontal rule before each prompt line

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

const Shell = enum {
    zsh,
    bash,
    unknown,
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

    .bright_black = "\x1b[90m",
    .bright_red = "\x1b[91m",
    .bright_green = "\x1b[92m",
    .bright_yellow = "\x1b[99m",
    .bright_blue = "\x1b[94m",
    .bright_magenta = "\x1b[95m",
    .bright_cyan = "\x1b[96m",
    .bright_white = "\x1b[97m",
};

pub var A: Allocator = undefined;
pub var E: Escapes = undefined;
pub var CWD: []u8 = undefined;

pub fn main() !void {
    // allocator setup
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    A = arena.allocator();

    // get the specified shell and initialize escape codes
    var shell = Shell.unknown;
    if (std.mem.len(os.argv) > 1) {
        var arg = std.mem.span(os.argv[1]);
        if (std.mem.eql(u8, arg, "zsh")) {
            shell = Shell.zsh;
        } else if ((std.mem.eql(u8, arg, "bash"))) {
            shell = Shell.bash;
        }
    }

    switch (shell) {
        .zsh => {
            E = Escapes.init("%{", "%}");
        },
        .bash => {
            E = Escapes.init("\\[", "\\]");
        },
        else => {
            E = Escapes.init("", "");
            const c = @cImport(@cInclude("stdlib.h"));
            _ = c.unsetenv("SHELL"); // force 'interactive' for subprograms
        },
    }

    // state
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    CWD = try std.os.getcwd(&buf);
    const long = funcs.is_env_true("PROMPT_LONG");

    // print prompt
    try funcs.newline_if("PROMPT_LINE_BEFORE");
    if (!funcs.is_env_true("PROMPT_BARE")) {
        try funcs.hr();
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
        try funcs.newline_if("PROMPT_LINE_AFTER");
    }
    try funcs.char();
}
