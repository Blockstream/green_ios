add_project_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')

sources = ['amount.hpp',
           'amount.cpp',
           'autobahn_wrapper.hpp',
           'assertion.hpp',
           'assertion.cpp',
           'boost_wrapper.hpp',
           'containers.hpp',
           'containers.cpp',
           'ffi_c.cpp',
           'ga_wally.hpp',
           'memory.hpp',
           'network_parameters.hpp',
           'session.hpp',
           'session.cpp',
           'transaction_utils.hpp',
           'transaction_utils.cpp',
           'utils.hpp',
           'utils.cpp',
           'common.h',
           'containers.h',
           'session.h',
           'utils.h']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

custom_target('fix-compile-commands', output : 'compile_commands.json', capture : true, command : ['sed', '-e', 's/-MD//g', '-e', 's/-pipe//g', 'compile_commands.json'])

if clang_tidy.found()
    custom_target('clang-tidy', output : 'clang-tidy', command : [clang_tidy, '-header-filter=../src/*',
      '-checks=*,-fuchsia*,-google-*,-llvm-*,-mpi-*,-objc-*,-zircon-*', '-p=' + join_paths(meson.build_root(), 'src')])
endif

dependencies = subproject_deps + [atomic_dep, m_dep, threads_dep, dl_dep]

link_args = []
link_whole = []
if build_jni
    message('Building JNI bindings...')
    subdir('swig_java')
    link_whole += [libswig_java]
    if build_machine.system() == 'linux' or host_machine.cpu_family().contains('android')
        wallycore_libdir = wallycore.get_variable('libdir')
        link_args += ['-Wl,--whole-archive', join_paths(wallycore_libdir, 'libwallycore.a'), join_paths(wallycore_libdir, 'libsecp256k1.a'), '-Wl,--no-whole-archive']
    endif
else
    message('Disabled JNI bindings')
endif

libga = library('greenaddress',
                sources,
                include_directories : incdir,
                link_whole : link_whole,
                link_args : link_args,
                dependencies : dependencies)

libga_dep = declare_dependency(include_directories : incdir, link_with : libga, dependencies : dependencies)

if host_machine.cpu_family().contains('iphone')
    output = 'single_arch_libgreenaddress_armv7.a'
    if host_machine.cpu_family().contains('sim')
        output = 'single_arch_libgreenaddress_x86_64.a'
    endif
    archiver = custom_target('archiver',
                             output : output,
                             command : [join_paths(meson.source_root(), 'tools', 'archiver.sh'), '--' + meson.get_cross_property('target_os'),
                                        meson.build_root()],
                             build_always : true,
                             build_by_default : true,
                             depends : libga)

    archiver_dep = declare_dependency(dependencies : libga_dep)
endif

# tests
subdirs = ['swift',
           'tests']
foreach n : subdirs
    subdir(n)
endforeach
