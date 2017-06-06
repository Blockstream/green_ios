project('sdk', ['c', 'cpp'], meson_version : '>= 0.40.1', default_options : ['cpp_std=c++14'])

# language related arguments
if not host_machine.cpu_family().contains('arm64') and not host_machine.cpu_family().contains('mips')
    add_project_arguments(['-flto'], language : 'cpp')
    add_project_link_arguments(['-flto'], language : 'cpp')
    if build_machine.system() == 'linux' or build_machine.cpu_family().contains('android')
        add_project_link_arguments(['-fuse-ld=gold'], language : 'cpp')
    endif
endif

swiftc = find_program('swiftc', required : false).found()
if swiftc
    swift = add_languages('swift', required : false)
    if swift
        add_project_arguments(['-I' + join_paths(meson.source_root(), 'src')], language : 'swift')
        add_project_link_arguments(['-L' + join_paths(meson.current_build_dir(), 'src')], language : 'swift')
    endif
endif

# dependencies
compiler = meson.get_compiler('cpp')

check_headers = [
    'fcntl.h',
    'sys/epoll.h',
    'sys/stat.h',
    'unistd.h'
]

foreach h : check_headers
    compiler.has_header(h)
endforeach

clang_format = find_program('clang-format', required : false)

threads_dep = dependency('threads')
m_dep = compiler.find_library('m', required : false)
atomic_dep = compiler.find_library('atomic', required : false)
dl_dep = compiler.find_library('dl', required : false)

subproject_libdirs = []
subproject_deps = []
subprojects = [['boost', 'boost_1_64_0', '>= 1.64.0', ['system', 'thread']],
               ['wallycore', 'libwally-core', '>= 0.1', []],
               ['openssl', 'openssl-1.0.2l', '>= 1.0.2', []]]

foreach sub : subprojects
    subproject_libdirs += join_paths(meson.current_build_dir(), sub[1], 'build', 'lib')
    dep = dependency(sub[0], modules : sub[3], version : '>= 9.9.9', required : false, static : true)
    if not dep.found()
        message('Building ' + sub[0] + '...')
        if not meson.is_cross_build()
            run_command(join_paths('tools', 'build' + sub[0] + '.sh'))
        else
            run_command(join_paths('tools', 'build' + sub[0] + '.sh'), '--' + meson.get_cross_property('target_os'))
        endif
        subproject_deps += dependency(sub[0], modules : sub[3], version : sub[2], static : true)
    endif
endforeach

subproject_deps += dependency('libsecp256k1', static : true)

add_project_link_arguments(['-lboost_system', '-lboost_thread'], language : 'cpp')

# includes
autobahn_inc_dir = join_paths(meson.current_build_dir().split('/')[-1], 'autobahn-cpp')
msgpack_inc_dir = join_paths(meson.current_build_dir().split('/')[-1], 'msgpack-2.1.1', 'include')
sdk_inc_dir = 'src'
websocketpp_inc_dir = join_paths(meson.current_build_dir().split('/')[-1], 'websocketpp-0.7.0')

incdir = include_directories([autobahn_inc_dir, msgpack_inc_dir, sdk_inc_dir, websocketpp_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach
