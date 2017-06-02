exe_names = ['wss_change_settings',
             'wss_change_settings_c',
             'wss_connect',
             'wss_get_tx_list',
             'wss_login',
             'wss_login_c',
             'wss_subscribe']

#if swiftc and swift
#    exe_names += 'wss_login_s'
#endif

sources = []
foreach name : exe_names
    if name.endswith('_c')
        sources += [name + '.c']
    elif name.endswith('_s')
        sources += [name + '.swift']
    else
        sources += [name + '.cpp']
    endif
endforeach

common_c_cpp_sources = ['argparser.h', 'argparser.c']

if clang_format.found()
    custom_target('tests/clang-format', input : sources + common_c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

foreach source : sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    if not source.endswith('.swift')
        exe_sources += common_c_cpp_sources
    endif
    exe = executable(exe_name, exe_sources,
                     include_directories : incdir,
                     dependencies : [libga_dep])
    test(exe_name, exe)
endforeach

