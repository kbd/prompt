set positional-arguments

build *args:
  zig build-exe prompt.zig "$@"

build-release *args:
  zig build-exe -OReleaseFast prompt.zig "$@"
