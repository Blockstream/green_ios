add_project_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')
foreach libdir : subproject_libdirs
    add_project_link_arguments(['-Wl,-rpath,' + libdir], language : 'cpp')
endforeach

sources = ['amount.hpp',
           'amount.cpp',
           'assertion.hpp',
           'assertion.cpp',
           'containers.hpp',
           'containers.cpp',
           'network_parameters.hpp',
           'session.hpp',
           'session.cpp',
           'utils.hpp',
           'utils.cpp',
           'common.h',
           'containers.h',
           'session.h',
           'utils.h']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

dependencies = [atomic_dep, m_dep, threads_dep] + subproject_deps + [dl_dep]

link_whole = []
link_args = []
if build_jni
    message('Building JNI bindings...')
    subdir('swig_java')
    link_whole += [libswig_java]
    link_args += ['-Wl,--whole-archive', '-lwallycore', '-Wl,--no-whole-archive']
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
