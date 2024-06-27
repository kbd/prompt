# prompt

Customizable prompt for unix shells

## Description

A command line is a fundamental interface to a computer.
The prompt is the status the computer shows the human before each command.

The prompt should:

- display as fast as possible
- give the human desired context for the next command
- be portable, not tied to a particular shell

I use this prompt as my daily driver.
The code is basically "done", but I'm always open to suggestions.

## Screenshots

Here are screenshots. First, a simple prompt:

![simple prompt](../media/short.png?raw=true)

Next, a more complex prompt, in a tmux session, with an active virtualenv, showing the user and host, in a git repository on 'my-branch' with a few files of different statuses, and finally indicating an active [direnv](https://direnv.net/).

![complex prompt](../media/long.png?raw=true)

Here's an example of job control and return code features.
This prompt has prefix disabled:

![job control](../media/jobs.png?raw=true)

This project depends on my other project, [repo_status](https://github.com/kbd/repo_status), to print source control status in the prompt.

Because I always wonder these things: the screenshots are in [Kitty terminal](https://sw.kovidgoyal.net/kitty/) using [Fantasque Sans Mono](https://github.com/belluzj/fantasque-sans).
All [my system config](https://github.com/kbd/setup) is open source if you're interested.

## Build instructions

Requires the Zig programming language to build:

```shell
$ git clone --recurse-submodules https://github.com/kbd/prompt.git
$ cd prompt
$ zig build-exe -OReleaseFast prompt.zig
$ cp prompt ~/bin  # copy binary to somewhere in your path
```

## Settings

Configurable environment variables:

```
$PROMPT_PREFIX
  prefix prompt with this text

$PROMPT_BARE
  set to enable a very minimal prompt. "zen mode"
  I use the following alias to toggle:
  alias pb='[[ $PROMPT_BARE ]] && unset PROMPT_BARE || export PROMPT_BARE=1'

$PROMPT_LONG
  display username@host even if local

$PROMPT_FULL_HOST
  if set, shows the full hostname (bash: \H \h -- zsh: %M %m)

$PROMPT_PATH
  show this for the path, overriding the cwd
  this enables you to use Zsh's hashed paths:
  export PROMPT_PATH="$(print -P '%~')"

$PROMPT_RETURN_CODE
  set to show the exit code of the previous program if != 0
  export PROMPT_RETURN_CODE=$?

$PROMPT_JOBS
  set to "{running} {suspended}" jobs, defaults to "0 0"
  for zsh: (https://unix.stackexchange.com/a/68635)
  export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}

$PROMPT_FULL_VENV
  set to show the full name of virtualenvs, vs an indicator

$PROMPT_LINE_BEFORE, $PROMPT_LINE_AFTER
  add newline before/after prompt, this enables a multi-line prompt

$PROMPT_HR
  set to $COLUMNS to print a horizontal rule before each prompt line
```

## Configuration

### Zsh

in .zshrc:

```zsh
setopt prompt_subst # execute the contents of PROMPT

alias title='printf "\e]0;%s\a"' # set window title
PROMPT='$(prompt zsh)'
precmd() {
  export PROMPT_RETURN_CODE=$?
  export PROMPT_JOBS=${(M)#${jobstates%%:*}:#running}\ ${(M)#${jobstates%%:*}:#suspended}
  export PROMPT_PATH="$(print -P '%~')"
  title "$PROMPT_PATH"
}
```

### Bash

in .bashrc

```bash
jobscount() {
  echo "$(jobs -rp | wc -l | tr -d ' ') $(jobs -sp | wc -l | tr -d ' ')"
}
PROMPT_COMMAND='PS1="$(PROMPT_RETURN_CODE=$? PROMPT_PATH="\w" PROMPT_JOBS="$(jobscount)" prompt bash)"'
```

### Nu shell

in `env.nu`:

```nu
let-env PROMPT_COMMAND = {
    let-env PROMPT_RETURN_CODE = $env.LAST_EXIT_CODE
    let-env PROMPT_HR = (term size | get columns)
    prompt
}
let-env PROMPT_INDICATOR = { "" }
```

### Xonsh

in .xonshrc:

```python
def prmpt():
  r = __xonsh__.history.rtns
  $PROMPT_RETURN_CODE = r[-1] if r else 0
  $PROMPT_PATH = "{short_cwd}"
  return $(prompt)

$PROMPT = prmpt
```
