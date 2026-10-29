// Folder Tagger Watcher — tiny launcher with no UI.
//
// The LaunchAgent starts this binary (inside "Folder Tagger Watcher.app", the
// Full Disk Access target) with the path of autotag.py as its only argument.
// It runs the script as a child and waits, so the child inherits the app's
// Full Disk Access. Unlike an AppleScript applet it has no startup screen that
// could pop up and block the watcher.

#include <spawn.h>
#include <stdio.h>
#include <sys/wait.h>

extern char **environ;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s /path/to/autotag.py\n", argv[0]);
        return 2;
    }
    char *args[] = {"/usr/bin/python3", "-I", argv[1], NULL};
    pid_t pid;
    int err = posix_spawn(&pid, args[0], NULL, NULL, args, environ);
    if (err != 0) {
        perror("posix_spawn");
        return 1;
    }
    int status;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
