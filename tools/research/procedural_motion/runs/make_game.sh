#!/bin/bash
cd "$(dirname "$0")/.."
run() { # shot dist az every
  EVERY=$4 .venv/bin/python game_gif.py $1 runs/game/$1.gif ../../../assets/characters/shared/mart.glb $2 $3
}
run walk_run 5.0 25 2
run stairs_up_down 5.5 25 2
run slope_up_down 6.0 25 2
run step_over_log 4.2 25 1
run duck_under_beam 4.2 25 1
run jump_wall 6.0 25 1
run push_recovery 4.0 25 1
run door_open 5.0 40 1
run around_obstacles 9.0 60 2
