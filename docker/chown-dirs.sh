#!/usr/bin/env bash

chown_r_dir() {
  dir=$1
  if [[ -d ${dir} ]] && [[ "$(stat -c %u:%g ${dir})" != "${FIXUID}:${FIXGID}" ]]; then
    echo chown -R $dir
    chown -R deploy:deploy $dir
  fi
}

chown_r_dir "${WORKSPACE_DIR}"
chown_r_dir /home/deploy/.config
chown_r_dir /home/deploy/.hex
chown_r_dir /home/deploy/.mix
chown_r_dir /home/deploy/.cache
