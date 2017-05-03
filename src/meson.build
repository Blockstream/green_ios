tls = get_option('with-tls')
if tls
    add_global_arguments('-DWITH_TLS', language : 'cpp')
endif

add_global_arguments(['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations', '-funsigned-char'], language : 'cpp')

sources = ['assertion.hpp', 'assertion.cpp', 'session.hpp', 'session.cpp']

if clang_format.found()
    custom_target('clang-format', input : sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

wally_path = join_paths(meson.current_source_dir(), 'wally', 'src', '.libs')
libwally_obj = compiler.find_library('wallycore', dirs : [wally_path])
libwally_linkargs = '-Wl,-rpath,' + wally_path

# FIXME: needs both options (shared and static). meson won't allow a version kw arg for library.
libga = shared_library('greenaddress', sources,
            version : '0.1.0',
            include_directories : incdir,
            link_args : libwally_linkargs,
            dependencies : [boostdep, ssldep, libwally_obj])

libga_dep = declare_dependency(
            include_directories : incdir,
            link_with : libga,
            dependencies : [boostdep, ssldep, libwally_obj])

# tests
subdirs = ['tests']
foreach n : subdirs
    subdir(n)
endforeach

