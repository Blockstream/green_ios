c_cpp_sources = [
    'parse_uri.cpp',
    'wss_change_settings.cpp',
    'wss_change_settings_c.c',
    'wss_connect.cpp',
    'wss_create_subaccount.cpp',
    'wss_get_tx_list.cpp',
    'wss_get_tx_list_c.c',
    'wss_login.cpp',
    'wss_login_c.c',
    'wss_login_new.cpp',
    'wss_login_proxy.cpp',
    'wss_send.cpp',
    'wss_subscribe.cpp'
]

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

c_cpp_args = []
link_args = []
if compiler.get_id() == 'gcc'
    c_cpp_args = ['-fpie']
    link_args = ['-Wl,-pie']
endif

foreach source : c_cpp_sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    exe = executable(exe_name,
                     exe_sources,
                     c_args : c_cpp_args,
                     cpp_args : c_cpp_args,
                     link_args : link_args,
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
