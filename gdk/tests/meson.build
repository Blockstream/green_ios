c_cpp_sources = [
    'wss_connect.cpp',
    'wss_create_subaccount.cpp',
    'wss_get_tx_list.cpp',
    'wss_get_tx_list_c.c',
    'wss_invalid_mnemonic.cpp',
    'wss_login.cpp',
    'wss_login_c.c',
    'wss_login_new.cpp',
    'wss_login_new_c.c',
    'wss_login_proxy.cpp',
    'wss_send.cpp',
    'wss_subscribe.cpp',
    'wss_system_messages.cpp',
    'wss_system_messages_c.c',
    'wss_twofactor.cpp'
]

common_c_cpp_sources = ['argparser.h',
                        'argparser.c',
                        'http_jsonrpc_interface.hpp',
                        'http_jsonrpc_interface.cpp',
                        'utils.cpp']

libtests_common = static_library('tests_common', common_c_cpp_sources, include_directories : incdir, dependencies : subproject_deps)
libtests_common_dep = declare_dependency(link_with : libtests_common)

if clang_format.found()
    custom_target('tests-clang-format', input : c_cpp_sources + common_c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

local_dependencies = subproject_deps + [libga_dep, threads_dep, libtests_common_dep]
link_depends = []
link_whole = [libtests_common]
if cross_iphone_build
    link_depends += [archiver]
else
    link_whole += [libga.get_static_lib()]
endif

foreach source : c_cpp_sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    exe = executable(exe_name,
                     exe_sources,
                     c_args : executable_c_cpp_args,
                     cpp_args : executable_c_cpp_args,
                     link_args : executable_link_args,
                     link_whole : link_whole,
                     link_depends : link_depends,
                     include_directories : incdir,
                     dependencies : local_dependencies)
    test(exe_name, exe, timeout : 120)
endforeach

if build_jni
    java_sources = ['WSSLogin',
                    'WSSWatchOnlyLogin']
    foreach source : java_sources
        target_name = source + '_java_test'
        command = ['javac', '-implicit:none', '-source', java_target, '-target', java_target,
                   '-classpath', '@OUTDIR@/../src/swig_java/GASDK.jar', '-d', '@OUTDIR@', '@INPUT@']
        if java_target == '1.7'
            command += ['-bootclasspath', join_paths(java_home, 'jre', 'lib', 'rt.jar')]
        endif

        test_target = custom_target(target_name,
                                    command : command,
                                    input : source + '.java',
                                    output : source + '.class',
                                    depends : swig_target)
        test(target_name, java,
             args : ['-Xcheck:jni', '-classpath', '.:../src/swig_java/GASDK.jar', '-Djava.library.path=.:../src', source],
             workdir : meson.current_build_dir(),
             depends : test_target)
    endforeach
endif
