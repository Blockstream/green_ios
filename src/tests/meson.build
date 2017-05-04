exe_names = ['wss_connect', 'wss_login', 'wss_subscribe']
foreach name : exe_names
    exe = executable(name, name + '.cpp',
                         include_directories : incdir,
                         dependencies : [libga_dep])
    test(name, exe)
endforeach

