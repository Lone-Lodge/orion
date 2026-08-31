# os

CLI and OS primitives for self-hosted tools, under the names `orbit` already
uses.

Three sources feed it:

- C externs from `orion_cli.c` - `sys_run`, filesystem ops, `exit`, `eprint`
- orion-self builtins re-exposed under friendlier names - `read_file` is
  `file_read`, `arg` is `argv`, and so on
- `run_command(cmd, [args])`, which joins to one line and calls `sys_run`

```orion
arg(1)                              # a command-line argument
read_file("x.or")   write_file(p, c)
run_command("clang", ["a.c", "-o", "a.exe"])
capture_stdout("git", ["rev-parse", "HEAD"])
id = start_command("server", [])    # background; command_result(id) later
```

## Watch out for

`modified_at` gives milliseconds since 1601 on Windows, not unix seconds.

This is the workspace's grab-bag: fifty public functions covering five
different jobs - processes, the filesystem, paths, the Windows registry, and
installer stitching. Nothing here is wrong, but "os" is the name it got by
being where things went, not by describing what it is. If it ever splits, those
five are the seams.
