"""Plot the clean and bouncing presses from the Lab 4 practice VCD."""

import math
import re
import sys
from pathlib import Path


SIGNALS = ("key_in", "click_pulse", "frame_tick", "screen_sel")
UNITS_MS = {"s": 1e3, "ms": 1, "us": 1e-3, "ns": 1e-6, "ps": 1e-9, "fs": 1e-12}


def read_traces(path):
    traces = {name: [] for name in SIGNALS}
    ids = {}
    with path.open(encoding="ascii") as stream:
        header = []
        for line in stream:
            header.append(line)
            fields = line.split()
            if fields[:1] == ["$var"] and fields[4] in traces:
                ids.setdefault(fields[3], fields[4])
            if "$enddefinitions" in line:
                break
        scale = re.search(r"\$timescale\s+(\d+)\s*(\w+)\s+\$end", "".join(header))
        unit = int(scale[1]) * UNITS_MS[scale[2]]
        now = 0
        for raw in stream:
            line = raw.strip()
            if not line or line.startswith("$"):
                continue
            if line.startswith("#"):
                now = int(line[1:]) * unit
                continue
            if line[0] in "bB":
                value, code = line[1:].split()
            else:
                value, code = line[0], line[1:]
            if code in ids:
                trace = traces[ids[code]]
                if value and set(value) <= {"0", "1"}:
                    level = int(value, 2)
                else:
                    level = None
                if not trace or trace[-1][1] != level:
                    trace.append((now, level))
    if any(not row for row in traces.values()):
        raise ValueError("Missing Lab 4 signals in the VCD header or data")
    return traces, now


def draw_window(path, traces, last_ms, pulse, title, filename, show_hold=False):
    change = next(t for t, v in traces["screen_sel"] if v == 1 and t >= pulse)
    start = max(0, pulse - 32)
    end = min(last_ms, max(change + 4, pulse + 8))
    if show_hold:
        end = next(t for t, v in traces["screen_sel"] if t > change and v == 0)
    left, right = 178, 927

    def x(t):
        return left + (right - left) * (t - start) / (end - start)

    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="980" height="348" viewBox="0 0 980 348">',
        '<rect width="980" height="348" fill="white"/>',
        '<g font-family="Arial, sans-serif" fill="#172b39">',
        f'<text x="24" y="30" font-size="20">{title}</text>',
        f'<text x="24" y="56" font-size="14">click_pulse rises at {pulse:.6f} ms. '
        f'screen_sel reaches 1 at {change:.6f} ms.</text>',
    ]
    tick_step = max(1, math.ceil((end - start) / 9))
    for tick in range(math.ceil(start / tick_step) * tick_step, math.ceil(end), tick_step):
        px = x(tick)
        svg.append(f'<path d="M {px:.3f} 73 V 280" stroke="#d4dde1"/>')
        svg.append(f'<text x="{px:.3f}" y="302" text-anchor="middle" font-size="13">{tick}</text>')
    for i, name in enumerate(SIGNALS):
        baseline = 111 + i * 53
        svg.append(f'<text x="24" y="{baseline-4}" font-family="monospace" font-size="16">{name}</text>')
        svg.append(f'<text x="157" y="{baseline-18}" font-size="10" fill="#516874">1</text>')
        svg.append(f'<text x="157" y="{baseline+3}" font-size="10" fill="#516874">0</text>')
        state = None
        commands = []
        cursor = start
        for time, value in traces[name] + [(end, None)]:
            if time < start:
                state = value
                continue
            stop = min(time, end)
            if state is not None:
                y = baseline - 20 * state
                commands.append(f'M{x(cursor):.5f} {y} H{x(stop):.5f}')
                if value is not None and time <= end:
                    commands.append(f'V{baseline - 20 * value}')
            if time >= end:
                break
            cursor, state = time, value
        svg.append(f'<path d="{" ".join(commands)}" stroke="#154b6e" stroke-width="2" fill="none"/>')
    svg.extend(['<text x="554" y="329" text-anchor="middle" font-size="14">Simulation time (ms)</text>',
                '</g></svg>'])
    destination = path.with_name(filename)
    destination.write_text("\n".join(svg), encoding="utf-8")
    print(f"Waveform figure: {destination}")


if __name__ == "__main__":
    source = Path(sys.argv[1])
    data, last = read_traces(source)
    pulses = [t for t, v in data["click_pulse"] if v == 1]
    draw_window(source, data, last, pulses[0], "First clean press", "first_press.svg")
    draw_window(source, data, last, pulses[3], "Bouncing press followed by a long hold",
                "bounce_hold.svg", show_hold=True)
