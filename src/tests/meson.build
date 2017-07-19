exe_names = ['wss_change_settings',
             'wss_change_settings_c',
             'wss_connect',
             'wss_get_tx_list',
             'wss_get_tx_list_c',
             'wss_login',
             'wss_login_c',
             'wss_login_new',
             'wss_subscribe']

#if swift
#    exe_names += ['wss_get_tx_list_s',
#                  'wss_login_s',
#                  'wss_login_new_s']
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
    custom_target('tests-clang-format', input : sources + common_c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

dependencies = [libga_dep]

if host_machine.cpu_family().contains('iphone')
    dependencies += [archiver_dep]
endif

foreach source : sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    deps = dependencies
    if not source.endswith('.swift')
        exe_sources += common_c_cpp_sources
    else
        deps += [ga_swift_module_dep]
    endif
    exe = executable(exe_name, exe_sources,
                     include_directories : incdir,
                     dependencies : deps)
    test(exe_name, exe)
endforeach

if build_jni
    java_sources = ['wss_connect',
                    'wss_login']
    foreach source : java_sources
        target_name = source + '_java_test'
        custom_target(target_name,
                      command : ['javac', '-classpath', '@OUTDIR@/../swig_java', '-d', '@OUTDIR@', '@INPUT@'],
                      input : source + '.java',
                      output : source + '.class',
                      depends : swig_target,
                      build_always : true)
        test(target_name, java,
             args : ['-classpath', '.:../swig_java', '-Djava.library.path=.:../swig_java:..', source],
             workdir : meson.current_build_dir())
    endforeach
endif
