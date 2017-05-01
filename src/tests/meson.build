exe_names = ['wss_connect', 'wss_subscribe']
foreach name : exe_names
    exe = executable(name, name + '.cpp',
                         include_directories : incdir,
                         dependencies : [boostdep, ssldep, libga_dependency])
    test(name, exe)
endforeach

