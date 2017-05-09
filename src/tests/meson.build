exe_names = ['wss_connect', 'wss_login', 'wss_login_c', 'wss_subscribe']
sources = []
foreach name : exe_names
    if name.endswith('_c')
        sources += [name + '.c']
    else
        sources += [name + '.cpp']
    endif
endforeach

if clang_format.found()
    custom_target('tests/clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

foreach source : sources 
    exe_name = source.split('.')[0]
    exe = executable(exe_name, source,
                         include_directories : incdir,
                         dependencies : [libga_dep])
    test(exe_name, exe)
endforeach

