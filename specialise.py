#!/usr/bin/env python3

import os
import sys
from glob import glob
from pprint import pprint
from typing import List, Dict, Tuple, Optional
from random import randint

iama: str = sys.argv[1]
name: str = sys.argv[2]
options_dir: str = sys.argv[3]


os.chdir(options_dir)
options: List[str] = glob("*")

viable_options: List[str] = [option for option in options if iama in option]

print(f"I am a: {iama}")
print(f"My name is: {name}")
print("all options:")
pprint(options)

print("viable options:")
pprint(viable_options)

if name in viable_options:
    print("my name is a viable option, forcing that.")
    viable_options = [name]

if len(viable_options) == 0:
    print("none! aborting!")
    sys.exit(1)

if len(viable_options) == 0:
    print("none! aborting!")
    sys.exit(1)

max_option_len: int = max([len(option) for option in viable_options])
option_favorability: Dict[str, int] = {}
for option in viable_options:
    option_favorability[option] = max_option_len - len(option) + 1
    try:
        with open(f"{option}/favorability") as fh:
            option_favorability[option] = int(fh.read())
    except Exception as e:
        print(f"error reading favorability for {option}")
        pprint(e)


option_ranges: List[Tuple[str, int]] = []
last_max: int = 0
for option, favorability in option_favorability.items():
    last_max = favorability + last_max
    option_ranges.append((option, last_max))

print("Assigned options with max ranges:")
pprint(option_ranges)

picked: int = randint(0, last_max)
print(f"from 0 to {last_max}, random selection: {picked}")
selected: Optional[str] = None
for option_range in option_ranges:
    if picked < option_range[1]:
        selected = option_range[0]
        print(f"picked: {selected}, (max: {option_range[1]})")
        break

if selected is not None:
    os.execv(
        f"{selected}/bin/switch-to-configuration",
        [f"{selected}/bin/switch-to-configuration", "switch"],
    )
