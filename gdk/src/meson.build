sources = ['../include/amount.hpp',
           'amount.cpp',
           '../include/assertion.hpp',
           'assertion.cpp',
           'autobahn_wrapper.hpp',
           'boost_wrapper.hpp',
           '../include/exception.hpp',
           'containers.hpp',
           'containers.cpp',
           'ffi_c.cpp',
           '../include/ga_wally.hpp',
           '../include/network_parameters.hpp',
           '../include/session.hpp',
           'ga_session.cpp',
           'ga_session.hpp',
           'ga_tx.cpp',
           'ga_tx.hpp',
           'logging.hpp',
           'memory.hpp',
           'session.cpp',
           'transaction_utils.cpp',
           'transaction_utils.hpp',
           '../include/twofactor.hpp',
           'twofactor.cpp',
           'twofactor_calls.hpp',
           'utils.hpp',
           'utils.cpp']

headers = ['../include/common.h',
           '../include/containers.h',
           '../include/session.h',
           '../include/twofactor.h',
           '../include/utils.h'
]

sources += headers

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

if clang_tidy.found()
    fix_compile_commands = custom_target('fix-compile-commands', output : 'compile_commands.json', capture : true, command : ['sed', '-e', 's/-MD//g', '-e', 's/-pipe//g', 'compile_commands.json'])
    custom_target('clang-tidy', output : 'clang-tidy', command : [clang_tidy, '-header-filter=../src/*',
                  '-checks=*,-fuchsia*,-google-*,-llvm-*,-mpi-*,-objc-*,-zircon-*', '-p=' + join_paths(meson.build_root(), 'src')],
                   depends : fix_compile_commands)
endif

dependencies = subproject_deps + [atomic_dep, m_dep, threads_dep, dl_dep, ws2_dep, bcrypt_dep, ssp_dep]

local_link_args = []
link_whole = []
if build_jni
    message('Building JNI bindings...')
    subdir('swig_java')
    link_whole += [libswig_java]
else
    message('Disabled JNI bindings')
endif

wallycore_libdir = wallycore.get_variable('libdir')
if host_machine.system() == 'linux' or cross_android_build
    local_link_args += ['-Wl,--whole-archive', join_paths(wallycore_libdir, 'libwallycore.a'), '-Wl,--no-whole-archive']
    if build_jni and build_machine.system() == 'darwin'
        local_link_args += ['-Wl,--whole-archive', join_paths(wallycore_libdir, '..', '..', 'src', '.libs', 'libswig_java.a'), '-Wl,--no-whole-archive']
    endif
elif build_machine.system() == 'darwin'
    local_link_args += ['-Wl,-force_load', join_paths(wallycore_libdir, 'libwallycore.a')]
endif

install_headers(
    headers,
    subdir : 'gdk'
)

if cross_android_build
    libga_installdir = join_paths('lib', meson.get_cross_property('ndk_lib_dir'))
else
    libga_installdir = join_paths('lib', host_machine.cpu() + '_' + host_machine.system())
endif

libga = both_libraries('greenaddress',
                        sources,
                        include_directories : incdir,
                        link_whole : link_whole,
                        link_args : local_link_args,
                        dependencies : dependencies,
                        install : true,
                        install_dir : libga_installdir)

libga_dep = declare_dependency(include_directories : incdir, link_with : libga.get_static_lib())

if cross_iphone_build
    output = 'allsym_libgreenaddress.a'
    archiver = custom_target('archiver',
                             output : output,
                             command : [join_paths(meson.source_root(), 'tools', 'archiver.sh'), meson.build_root()],
                             build_always_stale : true,
                             build_by_default : true,
                             depends : libga)
endif

# tests
subdirs = ['swift']
foreach n : subdirs
    subdir(n)
endforeach
