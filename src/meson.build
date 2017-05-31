add_project_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')
foreach libdir : subproject_libdirs
    add_project_link_arguments(['-Wl,-rpath,' + libdir], language : 'cpp')
endforeach

if compiler.get_id() == 'clang' and host_machine.cpu_family().contains('mips')
    add_project_arguments(['-mxgot'], language : 'cpp')
endif

sources = ['assertion.hpp',
           'assertion.cpp',
           'network_parameters.hpp',
           'session.hpp',
           'session.cpp',
           'utils.hpp',
           'utils.cpp',
           'session.h']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

dependencies = [atomic_dep, m_dep, threads_dep] + subproject_deps + [dl_dep]

libga = library('greenaddress', sources, include_directories : incdir, dependencies : dependencies)
libga_dep = declare_dependency(include_directories : incdir, link_with : libga, dependencies : dependencies)

# tests
subdirs = ['tests']
foreach n : subdirs
    subdir(n)
endforeach
