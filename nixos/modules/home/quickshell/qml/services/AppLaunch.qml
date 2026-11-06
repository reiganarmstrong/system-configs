pragma Singleton
// DesktopEntry.execute() does not honour Terminal=true in Quickshell 0.3.
import Quickshell

Singleton {
    // TERMINAL names one executable, as a command name or absolute path,
    // that runs "-e program args…". It is never split or run through a shell;
    // a value with arguments or other characters falls back to Ghostty.
    function terminalCommand(terminal: var, command: var): var {
        const valid = typeof terminal === "string" && /^[A-Za-z0-9_.+\/-]+$/.test(terminal) && !terminal.startsWith("-");
        if (terminal && !valid)
            console.warn("TERMINAL must be a single executable; using ghostty");
        return [valid ? terminal : "ghostty", "-e", ...command];
    }
    function launch(app: var): void {
        if (!app) return;
        if (app.runInTerminal) {
            Quickshell.execDetached({
                command: terminalCommand(Quickshell.env("TERMINAL"), app.command),
                workingDirectory: app.workingDirectory,
            });
        } else app.execute();
    }
}
