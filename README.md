# prompt

Customizable prompt for unix shells

## Description / Goals / Status

The command line is the fundamental interface to the computer. The prompt is the
status you see before every command you run.

The prompt should:

- display as fast as possible
- give you desired context for your command
- be portable, not tied to a particular shell

I use this prompt as my daily driver. The code is "done" but I'm always open to
suggestions.

Here are a couple screenshots. First, a simple prompt:

![simple prompt](../media/short.png?raw=true)

Next, a more complex prompt, in a tmux session, with a virtualenv and direnv
active, in a git repository with changes, staged files, etc.

![complex prompt](../media/long.png?raw=true)

This project depends on my other project,
[repo_status](https://github.com/kbd/repo_status) to print source control status
in the prompt.

## build instructions

Requires the Zig programming language to build:

```
$ zig build-exe -OReleaseFast prompt.zig
```

That creates a binary named `prompt`, which I put in `~/bin` so it's in my path.

## Settings

Configurable environment variables:

    $PROMPT_PREFIX - default ⚡
      override to control what's displayed at the start of the prompt line

    $PROMPT_BARE
      set to enable a very minimal prompt

    $PROMPT_FULL_HOST
      shows the full hostname (bash: \H \h -- zsh: %M %m)

    $PROMPT_LONG
      display username@host even if local

    $PROMPT_PATH
      set to use things like Zsh's hashed paths
      export PROMPT_PATH="$(print -P '%~')"

    $PROMPT_RETURN_CODE
      set to display the exit code of the previous program
      export PROMPT_RETURN_CODE=$?

    $PROMPT_JOBS
      set to "{running} {suspended}" jobs (separated by space, defaults to 0 0)
      for zsh: (https://unix.stackexchange.com/a/68635)
      export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}

    $PROMPT_FULL_VENV
      set to show the full name of virtualenvs vs an indicator

    $PROMPT_LINE_BEFORE, $PROMPT_LINE_AFTER
      set for a multiline prompt, if set, add newline before/after the prompt

## Configuration

Here's how to set the prompt in a Zsh config, taking advantage of some of the above options:

```zsh
alias title='printf "\e]0;%s\a"' # set window title
PROMPT='$(prompt zsh)'
precmd() {
  export PROMPT_RETURN_CODE=$?
  export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}
  export PROMPT_PATH="$(print -P '%~')"
  title "$PROMPT_PATH"
}
```
