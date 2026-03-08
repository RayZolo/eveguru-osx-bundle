#!/usr/bin/env nu

use std/log

let OLD_CONFIG = $env.HOME + '/.wine/drive_c/ProgramData/EveGuru/EveGuru.config'
let NEW_CONFIG = $env.HOME + '/.wine-eveguru/drive_c/ProgramData/EveGuru/EveGuru.config'


def copy_config [] {
  log info $'Copying ($OLD_CONFIG) to ($NEW_CONFIG)'
  mkdir ($NEW_CONFIG | path dirname)
  cp $OLD_CONFIG $NEW_CONFIG
}

def main [
  --force (-f)  # Always ask to migrate
] {
  log info 'Starting the migration process'

  log info 'Checking if the migration is needed'
  if (($OLD_CONFIG | path exists) and (not ($NEW_CONFIG | path exists) or $force)) {
    let title = 'Existing installation of EveGuru detected'
    let message = [
      'Would you like to keep using an already existing data directory?'
      'Answering \"Yes\" is safe and generally recommended.'
      'Answering \"No\" will require you to choose a new data directory, authenticate your characters, and download missing data.'
    ] | str join "\n"

    log info 'Asking the user to keep using an already existing data directory'
    let dialog = ^osascript -e $'display dialog "($message)" buttons {"No", "Yes"} default button "Yes" cancel button "No" with title "($title)" with icon caution' | complete

    match $dialog.exit_code {
      0 => { log info 'The user answered "Yes"'; copy_config }
      _ => { log info 'The user answered "No"' }
    }
  } else {
    log info 'The migration is not needed'
  }

  log info 'Finished the migration process'
}
