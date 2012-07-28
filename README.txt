[mplugin]

Simple project management tool for vim.
(require ruby runtime)

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
