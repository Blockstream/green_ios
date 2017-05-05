exe_names = ['wss_connect', 'wss_login', 'wss_subscribe']
sources = []
foreach name : exe_names
  sources += [name + '.cpp']
endforeach

if clang_format.found()
    custom_target('tests/clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

foreach name : exe_names
    exe = executable(name, name + '.cpp',
                         include_directories : incdir,
                         dependencies : [libga_dep])
    test(name, exe)
endforeach

