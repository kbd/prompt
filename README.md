# prompt

Customizable prompt for unix shells

## build instructions

```
$ zig build-exe -OReleaseFast prompt.zig
```

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

## Configuration

Here's how to set the prompt in a Zsh config, taking advantage of some of the above options:

```zsh
alias title='printf "\e]0;%s\a"' # set window title
PROMPT='$(prompt)'
precmd() {
  export PROMPT_RETURN_CODE=$?
  export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}
  export PROMPT_PATH="$(print -P '%~')"
  title "$PROMPT_PATH"
}
```
