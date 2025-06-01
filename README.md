# `with` REPL

`with` adds REPL-like capabilities to shell commands.

```bash
$ with echo a
echo a> b c             # will run `echo a b c` command
a b c
echo a> d e             # will run `echo a d e` command
a d e
```


It's a nice way to run the same command with changed arguments:

```bash
$ with docker container
docker container> run busybox echo hi
hi
docker container> ls -a | grep busy
44f0ca17927f   busybox                    "echo hi"                10 seconds ago   Exited (0) 9 seconds ago                                     tender_volhard
docker container> logs tender_volhard
hi
docker container> prune
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N] Y
Deleted Containers:
44f0ca17927f0f6af7188b368c1cc5547919f8486279c28163b1d2ffe1d1664f
...
```


## How to run

`with.scm` is an executable script written in [GNU Guile](https://www.gnu.org/software/guile).


You can run it directly:

```bash
$ ./with.scm echo a b
echo a b>
...
```

or after renaming and placing under $PATH:

```bash
$ with echo a b
echo a b>
...
```


## How to use

- Execute a base command with appended arguments:

    ```bash
    $ with echo a b
    echo a b> c d
    a b c d
    echo a b> | tr a-z A-Z && echo hi
    A B
    hi
    ```

- Supports mutliline arguments:

    ```bash
    echo a b> c\
    ... d\
    ... e
    a b cde
    echo a b> c \
    ... d \
    ... e
    a b c d e
    ```

- If you want to run the base command without additional arguments,
  input a space:

    ```bash
    echo a b> (space)
    a b
    ```

- You can append additional arguments to the base command using **`+`** prefix:

    ```bash
    echo a b> +c d
    echo a b c d>
    ```

- You can remove the argument(s) from the base command using **`-`** (or multiple of it):

    ```bash
    echo a b c d> -
    echo a b c> --
    echo a>
    ```

- Use `Ctrl+D` (EOT) or `Ctrl+C` (SIGINT) to exit the REPL.

- Run arbitrary shell commands using `!` prefix:

    ```bash
    echo a b> !ls
    README.md   with
    ```

- Set environment variables using `!` prefix:

    ```bash
    echo a b> !FOO=xyz
    echo a b> $FOO
    a b xyz
    echo a b> !FOO=$(pwd)
    echo a b> ${FOO##*/}
    a b with-repl
    ```


## Related work

- https://github.com/mbr/repl
- https://github.com/defunkt/repl

