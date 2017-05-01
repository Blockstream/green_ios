tls = get_option('with-tls')
if tls
    add_global_arguments('-DWITH_TLS', language : 'cpp')
endif

add_global_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations'], language : 'cpp')

sources = ['session.hpp', 'session.cpp']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

# FIXME: needs both options (shared and static). meson won't allow a version kw arg for library.
libga = shared_library('greenaddress', sources,
            version : '0.1.0',
            include_directories : incdir,
            dependencies : [boostdep, ssldep])

libga_dependency = declare_dependency(
            include_directories : incdir,
            link_with : libga,
            dependencies : [boostdep, ssldep])

# tests
subdirs = ['tests']
foreach n : subdirs
    subdir(n)
endforeach

