add_project_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')
add_project_link_arguments(['-Wl,-rpath,' + wally_lib_dir], language : 'cpp')
add_project_link_arguments(['-Wl,-rpath,' + boost_lib_dir], language : 'cpp')
add_project_link_arguments(['-Wl,-rpath,' + openssl_lib_dir], language : 'cpp')

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

# FIXME: needs both options (shared and static). meson won't allow a version kw arg for library.
libga = shared_library('greenaddress', sources,
            version : '0.0.0',
            include_directories : incdir,
            dependencies : [boost_dep, m_dep, threads_dep, openssl_dep, wally_dep])

libga_dep = declare_dependency(
            include_directories : incdir,
            link_with : libga,
            dependencies : [boost_dep, m_dep, threads_dep, openssl_dep, wally_dep])

# tests
subdirs = ['tests']
foreach n : subdirs
    subdir(n)
endforeach

