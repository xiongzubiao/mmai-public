#!/bin/bash

source logging.sh

function git_clone() {
  local args=$@
  git clone $1 $2 $3 $4 $5
  if [ $? -ne 0 ]; then
    div
    log_bad "'git clone $args' failed, exiting!"
    div
    exit 1
  fi
}