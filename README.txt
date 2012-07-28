[mplugin]

Simple project management tool for vim.
This plugin is using the ruby script. 

Install:
  Copy doc and plugin direcoties to your vim plugin directory.

Register project:

  ・Small Setting
    :MProjSet test dir='/projects/test'
    ... Set project root directory.

  ・Full Setting
    :MProjSet test dir='/projects/test' ext='\.java$|\.rb' srcdir='/project/test/src' docdir='/project/test/doc'
    ... Set project root directory, file extention pattern, source directory and document directory.

Select current project:

  :MProjSelect test

List projects:
  
  :MProjList

Jump to project root directory:

  :MProjJumpRootDir

Grep current project:

  :GG hogehoge

Find file in current project:

  :FF hoge.txt

Show current project in status line:

  :set statusline=%F%m%r%h%w\ %{MProjStatusLine()}

Special Grep command:

  :Grep -e "{filename-pattern}" {pattern} {directory}
  
  After called above command, [GrepResult] buffer will open.
  In [GrepResult] buffer, Those command is enabled:

  :{range}Substitute/{pattern}/{replaced}/{flag}
  ... Substitute texts in [GrepResult] buffer.

  :MGWrite
  ... Write changed line to each grepped file.

  :MGRepeat
  ... Re-Grep with same input parameter.

  :MGUpdate
  ... Update lines in [GrepResult] buffer to latest file contents.

  :MGWriteAndUpdate
  ... Execute :MGWrite and :MGUpdate commands.

  For more infomation, see doc/mgrep.jax.
    (This is japanese document. I'm poor at english ... orz)
  GG/FF commmand call this command internally.
