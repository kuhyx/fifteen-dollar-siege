"""When a run is recorded: kuhy's own dev play, never bots, tests or headless runs."""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

# Game args that only a bot or a test run carries.
BOT_ARGS = ("--autodrive", "--result-file=", "--expect-window=", "--screenshot-dir=", "--save-dir=", "--dev-shot=")
# Environment that marks a test, an agent or an explicit opt-out. The flags are on
# only as "1" (the scripts' own convention); a feedback dir is a path, any value counts.
BLOCKING_FLAGS = ("SIEGE_NO_RECORD",)
BLOCKING_PATH = "SIEGE_FEEDBACK_DIR"


@dataclass(frozen=True)
class Decision:
    record: bool
    reason: str


def arg_value(args: Sequence[str], prefix: str) -> str:
    """The value of the first `<prefix>value` argument, "" when absent."""
    for arg in args:
        if arg.startswith(prefix):
            return arg[len(prefix) :]
    return ""


def _engine_blocker(args: Sequence[str]) -> str:
    """Why the engine arguments (before `--`) make this a headless or muted run."""
    engine = list(args[: args.index("--")]) if "--" in args else list(args)
    if "--headless" in engine:
        return "--headless"
    for flag, value in (("--display-driver", "headless"), ("--audio-driver", "Dummy")):
        if flag in engine and engine[engine.index(flag) + 1 : engine.index(flag) + 2] == [value]:
            return f"{flag} {value}"
    return ""


def decide(args: Sequence[str], env: Mapping[str, str], force: bool = False) -> Decision:
    """Record only a windowed dev run on a real display; `force` is for tests."""
    if not env.get("DISPLAY"):
        return Decision(False, "no DISPLAY")
    if force:
        return Decision(True, "forced")
    for name in BLOCKING_FLAGS:
        if env.get(name) == "1":
            return Decision(False, f"{name}=1")
    if env.get(BLOCKING_PATH):
        return Decision(False, f"{BLOCKING_PATH} is set")
    if "--no-dev" in args or "--dev" not in args:
        return Decision(False, "not a --dev run")
    for marker in BOT_ARGS:
        hit = next((a for a in args if a.startswith(marker)), "")
        if hit:
            return Decision(False, f"bot or test run ({hit})")
    blocker = _engine_blocker(args)
    if blocker:
        return Decision(False, f"headless or muted run ({blocker})")
    return Decision(True, "dev play")
