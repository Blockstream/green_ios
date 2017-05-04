tls = get_option('with-tls')
if tls
    add_global_arguments('-DWITH_TLS', language : 'cpp')
endif

add_global_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')

sources = ['assertion.hpp', 'assertion.cpp', 'session.hpp', 'session.cpp']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

boost_linkargs = '-Wl,-rpath,' + boost_lib_path
wally_linkargs = '-Wl,-rpath,' + wally_path

# FIXME: needs both options (shared and static). meson won't allow a version kw arg for library.
libga = shared_library('greenaddress', sources,
            version : '0.1.0',
            include_directories : incdir,
            link_args : [boost_linkargs, wally_linkargs],
            dependencies : [boost_system_obj, boost_thread_obj, pthread_dep, ssldep, wally_obj])

libga_dep = declare_dependency(
            include_directories : incdir,
            link_with : libga,
            link_args : [boost_linkargs, wally_linkargs],
            dependencies : [boost_system_obj, boost_thread_obj, pthread_dep, ssldep, wally_obj])

# tests
subdirs = ['tests']
foreach n : subdirs
    subdir(n)
endforeach

