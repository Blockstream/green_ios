exe_names = ['parse_uri',
             'wss_change_settings',
             'wss_change_settings_c',
             'wss_connect',
             'wss_create_subaccount',
             'wss_get_tx_list',
             'wss_get_tx_list_c',
             'wss_login',
             'wss_login_c',
             'wss_login_new',
             'wss_send',
             'wss_subscribe']

c_cpp_sources = []
foreach name : exe_names
    if name.endswith('_c')
        c_cpp_sources += [name + '.c']
    else
        c_cpp_sources += [name + '.cpp']
    endif
endforeach

common_c_cpp_sources = ['argparser.h',
                        'argparser.c',
                        'http_jsonrpc_interface.hpp',
                        'http_jsonrpc_interface.cpp']

libtests_common = static_library('tests_common', common_c_cpp_sources, include_directories : incdir, dependencies : subproject_deps)
libtests_common_dep = declare_dependency(link_with : libtests_common)

if clang_format.found()
    custom_target('tests-clang-format', input : c_cpp_sources + common_c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

dependencies = [libga_dep, libtests_common_dep]

if host_machine.cpu_family().contains('iphone')
    dependencies += [archiver_dep]
endif

foreach source : c_cpp_sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    exe = executable(exe_name, exe_sources,
                     include_directories : incdir,
                     dependencies : dependencies)
    test(exe_name, exe, timeout : 120)
endforeach

if build_jni
    java_sources = ['wss_connect',
                    'wss_login']
    foreach source : java_sources
        target_name = source + '_java_test'
        custom_target(target_name,
                      command : ['javac', '-implicit:none', '-bootclasspath', join_paths(java_home, 'jre', 'lib', 'rt.jar'), '-source', '1.7',
                                 '-target', '1.7', '-classpath', '@OUTDIR@/../swig_java/GASDK.jar', '-d', '@OUTDIR@', '@INPUT@'],
                      input : source + '.java',
                      output : source + '.class',
                      depends : swig_target,
                      build_always : true)
        test(target_name, java,
             args : ['-classpath', '.:../swig_java/GASDK.jar', '-Djava.library.path=.:..', source],
             workdir : meson.current_build_dir())
    endforeach
endif
