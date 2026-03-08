#!/usr/bin/env nu

use std/log
use std/xml xaccess

const BUNDLE_DIR = path self | path dirname -n 3
const RESOURCES_DIR = $BUNDLE_DIR + '/Contents/Resources'
const EVEGURU_EXE = $RESOURCES_DIR + '/EveGuru.exe'

const RELEASE_URL = 'https://app.eveguru.online/app/api/updateinfo'
const RELEASE_CHANNEL = {'stable': 'latestStable', 'preview': 'latestTest'}

$env.WINEPREFIX = $env.HOME + '/.wine-eveguru'

let PROGRAM_DATA_DIR = $env.WINEPREFIX + '/drive_c/ProgramData/EveGuru'
let PROGRAM_DATA_CONFIG = $PROGRAM_DATA_DIR + '/EveGuru.config'
let EVEGURU_VERSION = $PROGRAM_DATA_DIR + '/version.json'


def get_data_directory [] {
  if not ($PROGRAM_DATA_CONFIG | path exists) {
    return ($BUNDLE_DIR + '/Contents/Data')
  }

  open $PROGRAM_DATA_CONFIG
    | from xml
    | xaccess ['configuration' 'appSettings' 'add']
    | where attributes.key == 'dataDirectory'
    | get attributes.value.0
    | str replace 'Z:' ''
    | str replace -a '\' '/'
}

def is_installed [] {
  $EVEGURU_EXE | path exists
}

def get_release_channel [] {
  let eveguru_config = (get_data_directory) + '/EveGuru.config'

  if not ($eveguru_config | path exists) {
    return $RELEASE_CHANNEL.stable
  }

  open $eveguru_config
    | from xml
    | xaccess ['configuration' 'appUpdateSettings' 'settings' 'option']
    | where attributes.name == 'enablePreviewUpdates'
    | get -o attributes.check.0
    | if ($in == 'true') { $RELEASE_CHANNEL.preview } else { $RELEASE_CHANNEL.stable }
}

def install [channel: string] {
  let release = http get $RELEASE_URL | get $channel
  let url = $release.app.downloadUrl
  let version = $release.app.version
  let file = mktemp -t

  log info $'Downloading ($url)'
  http get $url | save -f -p $file
  ^unzip -o $file -d $RESOURCES_DIR

  rm $file

  mkdir $PROGRAM_DATA_DIR
  {'version': $version} | save -f $EVEGURU_VERSION
}

def main [] {
  log info 'Checking if the app is installed'
  if (is_installed) {
    log info 'Checking if there are updates'
    let channel = get_release_channel
    let release = http get $RELEASE_URL | get $channel
    let old_version = try { open $EVEGURU_VERSION | get version } catch { '0.0.0' }
    let new_version = $release.app.version
    if ($new_version > $old_version) {
      log info $'An update from ($old_version) to ($new_version) is available'
      install $channel
    }
  } else {
    log info 'Installing the latest stable version'
    install $RELEASE_CHANNEL.stable
  }

  log info 'Launching'
  exec wine $EVEGURU_EXE -linux -macCrossover
}
