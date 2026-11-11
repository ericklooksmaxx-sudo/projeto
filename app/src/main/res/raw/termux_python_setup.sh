#!/data/data/com.termux/files/usr/bin/bash
# termux-python-setup - set up a Python environment in Termux.
#
# Installed by the Termux app to $PREFIX/bin/termux-python-setup and launched from
# "Python environment" in the drawer or the terminal long-press menu.
#
# Packages are installed from the Termux repositories when they exist there (prebuilt for
# Android, much faster and more reliable than building with pip), with pip as fallback for
# pure Python packages.

set -u

VERSION=1
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
EXAMPLES_DIR="${HOME:-/data/data/com.termux/files/home}/python-examples"
ASSUME_YES=0
FAILED=()
INSTALLED=()

if [ -t 1 ]; then
	B=$'\e[1m'; G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
	B=""; G=""; R=""; Y=""; C=""; N=""
fi

info() { printf '%s==>%s %s\n' "$C$B" "$N" "$*"; }
ok() { printf ' %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf ' %s!%s %s\n' "$Y" "$N" "$*"; }
fail() { printf ' %s✘%s %s\n' "$R" "$N" "$*"; }

usage() {
	cat <<EOF
${B}termux-python-setup${N} v$VERSION - install Python, PyTorch and UI libraries in Termux.

Usage: termux-python-setup [options] [profile...]

Profiles:
  base     Python and pip (always installed)
  ui       Terminal user interface libraries: rich, textual, prompt_toolkit,
           urwid, npyscreen, pytermgui, asciimatics, blessed, questionary
           (and curses, which is part of Python)
  torch    PyTorch (torch) with NumPy, for 64-bit devices (aarch64 / x86_64)
  data     NumPy, SciPy, pandas, matplotlib, Pillow, scikit-learn
  web      Browser based interfaces: Flask, PyWebIO (open http://localhost:PORT)
  gui      Desktop GUIs through Termux:X11: tkinter, PyQt5, pygame
  all      All of the above

Options:
  -y, --yes      Do not ask for confirmation
  -c, --check    Only show which Python libraries can be imported
  -e, --examples Only (re)create the example programs in ~/python-examples
  -h, --help     Show this help

Without a profile, "base ui torch" is installed.
EOF
}

# Return success if a package has an install candidate in the enabled apt repositories.
pkg_available() {
	local candidate
	candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
	[ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

pkg_installed() {
	dpkg -s "$1" >/dev/null 2>&1
}

# Install the first available package from a list of candidate Termux package names.
# Usage: install_pkg "label" candidate...
install_pkg() {
	local label="$1"; shift
	local name
	for name in "$@"; do
		if pkg_installed "$name"; then
			ok "$label ($name already installed)"
			INSTALLED+=("$label")
			return 0
		fi
	done
	for name in "$@"; do
		if pkg_available "$name"; then
			if apt-get install -y "$name"; then
				ok "$label ($name)"
				INSTALLED+=("$label")
				return 0
			fi
		fi
	done
	return 1
}

# Install with the Termux package manager and fall back to pip.
# Usage: install_lib "label" "pip-name" candidate...
install_lib() {
	local label="$1" pip_name="$2"; shift 2
	if [ "$#" -gt 0 ] && install_pkg "$label" "$@"; then
		return 0
	fi
	if [ -n "$pip_name" ]; then
		info "Installing $label with pip"
		if python -m pip install --upgrade "$pip_name"; then
			ok "$label (pip: $pip_name)"
			INSTALLED+=("$label")
			return 0
		fi
	fi
	fail "$label could not be installed"
	FAILED+=("$label")
	return 1
}

enable_repo() {
	local repo="$1"
	if ! pkg_installed "$repo"; then
		info "Enabling $repo"
		apt-get install -y "$repo" && apt-get update || warn "Could not enable $repo"
	fi
}

is_64bit() {
	case "$(uname -m)" in
		aarch64|arm64|x86_64) return 0 ;;
		*) return 1 ;;
	esac
}

setup_base() {
	info "Updating package lists"
	apt-get update || warn "apt-get update failed, check your mirror with 'termux-change-repo'"
	install_lib "Python" "" python || { fail "Python is required, aborting"; exit 1; }
	# pip is a separate package in Termux. Do not upgrade it with pip itself, that breaks the
	# package managed by apt.
	install_lib "pip" "" python-pip || true
}

setup_ui() {
	info "Terminal user interface libraries"
	# curses is part of the python package (it depends on ncurses).
	install_lib "Rich" "rich" python-rich
	install_lib "Textual" "textual" python-textual
	install_lib "prompt_toolkit" "prompt_toolkit" python-prompt-toolkit
	install_lib "urwid" "urwid" python-urwid
	install_lib "npyscreen" "npyscreen"
	install_lib "PyTermGUI" "pytermgui"
	install_lib "blessed" "blessed" python-blessed
	install_lib "questionary" "questionary"
	# asciimatics needs Pillow, which must come from the Termux repository.
	install_pkg "Pillow" python-pillow || true
	install_lib "asciimatics" "asciimatics"
}

setup_torch() {
	info "PyTorch"
	if ! is_64bit; then
		fail "PyTorch is only available for 64-bit devices, this device is $(uname -m)"
		FAILED+=("PyTorch")
		return 1
	fi
	install_lib "NumPy" "" python-numpy
	if ! install_pkg "PyTorch" python-torch; then
		enable_repo tur-repo
		install_pkg "PyTorch" python-torch || {
			fail "PyTorch could not be installed. There are no PyTorch wheels for Android on PyPI,"
			fail "so it must come from the Termux (or TUR) repositories: 'pkg install python-torch'."
			FAILED+=("PyTorch")
			return 1
		}
	fi
	install_pkg "torchvision" python-torchvision || warn "torchvision is not available in the enabled repositories (optional)"
	install_pkg "torchaudio" python-torchaudio || warn "torchaudio is not available in the enabled repositories (optional)"
}

setup_data() {
	info "Data science libraries"
	install_lib "NumPy" "" python-numpy
	install_pkg "Pillow" python-pillow || { FAILED+=("Pillow"); fail "Pillow could not be installed"; }
	if ! install_pkg "SciPy" python-scipy; then
		enable_repo tur-repo
		install_pkg "SciPy" python-scipy || { FAILED+=("SciPy"); fail "SciPy could not be installed"; }
	fi
	install_lib "matplotlib" "" matplotlib python-matplotlib || true
	if ! install_pkg "pandas" python-pandas; then
		enable_repo tur-repo
		install_lib "pandas" "pandas" python-pandas || true
	fi
	install_pkg "scikit-learn" python-scikit-learn || {
		enable_repo tur-repo
		install_pkg "scikit-learn" python-scikit-learn || warn "scikit-learn is not available in the enabled repositories (optional)"
	}
}

setup_web() {
	info "Browser based interface libraries"
	install_lib "Flask" "flask" python-flask
	install_lib "PyWebIO" "pywebio"
	echo "   Start a server on localhost and open it with: termux-open-url http://localhost:8080"
}

setup_gui() {
	info "Desktop GUI libraries (shown with the Termux:X11 app)"
	enable_repo x11-repo
	install_pkg "Termux:X11 server" termux-x11-nightly || warn "termux-x11-nightly not available, install the Termux:X11 app and package manually"
	install_lib "tkinter" "" python-tkinter
	install_lib "PyQt5" "" python-pyqt5 || true
	install_lib "pygame" "" python-pygame || true
	cat <<EOF
   To show desktop windows, install the Termux:X11 app (https://github.com/termux/termux-x11)
   and run your program with:
     termux-x11 :0 &
     DISPLAY=:0 python ~/python-examples/tk_demo.py
EOF
}

create_examples() {
	mkdir -p "$EXAMPLES_DIR" || return 1

	cat > "$EXAMPLES_DIR/rich_demo.py" <<'EOF'
"""Rich demo: tables, progress bars and colors. Run: python rich_demo.py"""
import time
from rich.console import Console
from rich.progress import track
from rich.table import Table

console = Console()
table = Table(title="Termux + Rich")
table.add_column("Library", style="cyan")
table.add_column("What it does", style="magenta")
table.add_row("rich", "Pretty output, tables, markdown, progress bars")
table.add_row("textual", "Full TUI apps with widgets, CSS and mouse support")
table.add_row("prompt_toolkit", "Interactive prompts and full screen apps")
console.print(table)
for _ in track(range(30), description="Working..."):
    time.sleep(0.03)
console.print("[bold green]Done![/] Truecolor: [#ff8800]orange[/] [#00aaff]blue[/]")
EOF

	cat > "$EXAMPLES_DIR/textual_demo.py" <<'EOF'
"""Textual demo: a counter app. Tap the buttons or press +/-, q to quit.
Run: python textual_demo.py"""
from textual.app import App, ComposeResult
from textual.containers import Horizontal
from textual.widgets import Button, Footer, Header, Static


class Counter(App):
    CSS = """
    Static { content-align: center middle; height: 5; text-style: bold; }
    Horizontal { align: center middle; height: auto; }
    Button { margin: 0 1; }
    """
    BINDINGS = [("plus", "change(1)", "Add"), ("minus", "change(-1)", "Remove"), ("q", "quit", "Quit")]

    count = 0

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield Static("0", id="value")
        with Horizontal():
            yield Button("-", id="minus", variant="error")
            yield Button("+", id="plus", variant="success")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.action_change(1 if event.button.id == "plus" else -1)

    def action_change(self, delta: int) -> None:
        self.count += delta
        self.query_one("#value", Static).update(str(self.count))


if __name__ == "__main__":
    Counter().run()
EOF

	cat > "$EXAMPLES_DIR/torch_demo.py" <<'EOF'
"""PyTorch demo: train a tiny network to learn y = 2x + 1 on the CPU.
Run: python torch_demo.py"""
import torch

print("PyTorch", torch.__version__, "| threads:", torch.get_num_threads())
x = torch.linspace(-1, 1, 64).unsqueeze(1)
y = 2 * x + 1
model = torch.nn.Linear(1, 1)
optimizer = torch.optim.SGD(model.parameters(), lr=0.1)
for step in range(200):
    loss = torch.nn.functional.mse_loss(model(x), y)
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    if step % 50 == 0:
        print(f"step {step:3d}  loss {loss.item():.5f}")
w, b = model.weight.item(), model.bias.item()
print(f"learned: y = {w:.3f}x + {b:.3f}  (expected y = 2x + 1)")
EOF

	cat > "$EXAMPLES_DIR/tk_demo.py" <<'EOF'
"""tkinter demo, needs the Termux:X11 app.
Run: termux-x11 :0 &  then  DISPLAY=:0 python tk_demo.py"""
import tkinter as tk

root = tk.Tk()
root.title("Termux tkinter")
label = tk.Label(root, text="Hello from Termux!", font=("sans", 18))
label.pack(padx=20, pady=20)
clicks = tk.IntVar(value=0)
tk.Button(root, text="Click me", command=lambda: clicks.set(clicks.get() + 1)).pack()
tk.Label(root, textvariable=clicks).pack(pady=10)
root.mainloop()
EOF

	cat > "$EXAMPLES_DIR/web_demo.py" <<'EOF'
"""PyWebIO demo: a form in the browser.
Run: python web_demo.py  then  termux-open-url http://localhost:8080"""
from pywebio import start_server
from pywebio.input import input, NUMBER
from pywebio.output import put_markdown


def app():
    name = input("What is your name?")
    age = input("How old are you?", type=NUMBER)
    put_markdown(f"## Hello {name}!\nIn 10 years you will be **{age + 10}**.")


if __name__ == "__main__":
    start_server(app, port=8080, host="127.0.0.1")
EOF

	ok "Examples in $EXAMPLES_DIR"
}

check_imports() {
	command -v python >/dev/null 2>&1 || { fail "Python is not installed"; return 1; }
	info "Python libraries"
	python - <<'EOF'
import importlib

libs = [
    ("curses", "curses"), ("rich", "Rich"), ("textual", "Textual"),
    ("prompt_toolkit", "prompt_toolkit"), ("urwid", "urwid"), ("npyscreen", "npyscreen"),
    ("pytermgui", "PyTermGUI"), ("asciimatics", "asciimatics"), ("blessed", "blessed"),
    ("questionary", "questionary"), ("numpy", "NumPy"), ("torch", "PyTorch"),
    ("torchvision", "torchvision"), ("scipy", "SciPy"), ("pandas", "pandas"),
    ("matplotlib", "matplotlib"), ("PIL", "Pillow"), ("sklearn", "scikit-learn"),
    ("flask", "Flask"), ("pywebio", "PyWebIO"), ("tkinter", "tkinter"),
    ("PyQt5", "PyQt5"), ("pygame", "pygame"),
]
for module, label in libs:
    try:
        m = importlib.import_module(module)
        version = getattr(m, "__version__", getattr(m, "VERSION", ""))
        print(f" \033[32m✔\033[0m {label:16} {version}")
    except Exception:
        print(f" \033[90m-\033[0m {label:16} not installed")
EOF
}

PROFILES=()
ONLY_CHECK=0
ONLY_EXAMPLES=0
for arg in "$@"; do
	case "$arg" in
		-y|--yes) ASSUME_YES=1 ;;
		-c|--check) ONLY_CHECK=1 ;;
		-e|--examples) ONLY_EXAMPLES=1 ;;
		-h|--help) usage; exit 0 ;;
		base|ui|torch|data|web|gui) PROFILES+=("$arg") ;;
		all) PROFILES+=(ui torch data web gui) ;;
		*) echo "Unknown argument: $arg" >&2; usage >&2; exit 1 ;;
	esac
done

if [ "$ONLY_CHECK" = 1 ]; then check_imports; exit $?; fi
if [ "$ONLY_EXAMPLES" = 1 ]; then create_examples; exit $?; fi

[ "${#PROFILES[@]}" -eq 0 ] && PROFILES=(ui torch)

printf '%sTermux Python setup%s\n' "$B" "$N"
echo "Profiles: base ${PROFILES[*]}"
if [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
	read -r -p "Continue? [Y/n] " answer
	case "${answer:-y}" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac
fi

export DEBIAN_FRONTEND=noninteractive
setup_base
declare -A DONE=()
for profile in "${PROFILES[@]}"; do
	[ -n "${DONE[$profile]:-}" ] && continue
	DONE[$profile]=1
	case "$profile" in
		base) ;;
		ui) setup_ui ;;
		torch) setup_torch ;;
		data) setup_data ;;
		web) setup_web ;;
		gui) setup_gui ;;
	esac
done

create_examples
echo
check_imports
echo
if [ "${#FAILED[@]}" -gt 0 ]; then
	warn "Not installed: ${FAILED[*]}"
	warn "Run 'termux-python-setup' again later or install them manually."
else
	ok "Python environment is ready. Try: python ~/python-examples/rich_demo.py"
fi
[ "${#FAILED[@]}" -eq 0 ]
