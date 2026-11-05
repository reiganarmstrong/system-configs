// The desktop shell. Per-screen surfaces are created for every monitor;
// everything else is a single instance that opens on the focused screen.
import Quickshell
import qs.modules

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property ShellScreen modelData

            Wallpaper { screen: screenScope.modelData }
            Bar { screen: screenScope.modelData }
        }
    }
}
