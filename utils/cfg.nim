import os
import ospaths

import ./log

proc get_cfg_file(): string =
   ## Walk from the current directory up to the root directory searching for
   ## a configuraiton file. Lastly, look in the user's home directory.
   const CFG_FILENAME = ".lins.cfg"
   result = ""

   for path in parent_dirs(expand_filename("./"), false, true):
      let tmp = path / CFG_FILENAME
      if file_exists(tmp):
         return tmp

   let tmp = get_home_dir() / CFG_FILENAME
   if file_exists(tmp):
      return tmp

proc parse_cfg_file*() =
   let cfg_file = get_cfg_file()
   if cfg_file == "":
      log.info("Unable to find configuration file.")
   else:
      log.info("Using configuration file '$#'.", cfg_file)
