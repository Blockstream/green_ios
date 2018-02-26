project('sdk', ['c', 'cpp'], meson_version : '>= 0.41.1', default_options : ['cpp_std=c++14'])

# header checks (must be architecture independent)
compiler = meson.get_compiler('cpp')

check_headers = [
    'fcntl.h',
    'stddef.h',
    'stdint.h',
    'string.h',
    'sys/epoll.h',
    'sys/stat.h',
    'time.h',
    'unistd.h'
]

foreach h : check_headers
    compiler.has_header(h)
endforeach

# language related arguments
if not host_machine.cpu_family().contains('arm64') and not host_machine.cpu_family().contains('mips')
    if get_option('lto')
        add_project_arguments(['-flto'], language : 'cpp')
        add_project_link_arguments(['-flto'], language : 'cpp')
    endif
    if build_machine.system() == 'linux' or host_machine.cpu_family().contains('android')
        add_project_link_arguments(['-fuse-ld=gold', '-ldl'], language : 'cpp')
    endif
endif

add_project_arguments(['-Wextra'], language : ['c', 'cpp'])

if compiler.get_id() == 'clang' and host_machine.cpu_family().contains('mips')
    add_project_arguments(['-mxgot'], language : 'cpp')
endif

if meson.version().version_compare('>= 0.44.0') and get_option('b_sanitize') == 'address'
    add_project_arguments(['-shared-libasan'], language : ['c', 'cpp'])
    add_project_link_arguments(['-shared-libasan'], language : ['c', 'cpp'])
endif

if get_option('buildtype') == 'debug'
    add_project_arguments(['-Og', '-g', '-fno-omit-frame-pointer'], language : ['c', 'cpp'])
endif

if meson.is_cross_build()
    archs = meson.get_cross_property('archs')
    if archs != ''
        add_project_arguments(meson.get_cross_property('archs'), language : ['c', 'cpp'])
    endif
    if host_machine.cpu_family().contains('iphone')
        add_project_arguments(['-fembed-bitcode'], language : lang)
    endif
endif

swift = add_languages('swift', required : false)
if swift
    add_project_arguments(['-I' + join_paths(meson.source_root(), 'src')], language : 'swift')
    add_project_arguments(['-I' + join_paths(meson.build_root(), 'libwally-core', 'include')], language : 'swift')
    add_project_arguments(['-I' + join_paths(meson.source_root(), 'src', 'swift', 'GreenAddress', '.build', 'debug')], language : 'swift')
    add_project_link_arguments(['-L' + join_paths(meson.build_root(), 'src')], language : 'swift')
    add_project_link_arguments(['-L' + join_paths(meson.source_root(), 'src', 'swift', 'GreenAddress')], language : 'swift')
    add_project_link_arguments(['-lGreenAddress'], language : 'swift')
    add_project_link_arguments(['-lPromiseKit'], language : 'swift')
endif

swig = find_program('swig', required : false)
if swig.found()
    pymodule = import('python3')
    python3 = pymodule.find_python()
    res = run_command(python3, '-c', 'import os; print(os.environ["JAVA_HOME"], end = "")')
    if res.returncode() == 0
        java_home = res.stdout()
        message('JAVA_HOME set to ' + java_home)
    else
        java_home = ''
    endif
    javac = add_languages('java', required : false)
    if not javac or java_home == ''
        message('Java not found or $JAVA_HOME not set. JNI bindings are disabled.')
    else
        java = find_program('java')
    endif
endif

build_jni = swig.found() and javac and java_home != '' and not host_machine.cpu_family().contains('iphone')

# dependencies
clang_format = find_program('clang-format', required : false)

threads_dep = dependency('threads')
m_dep = compiler.find_library('m', required : false)
atomic_dep = compiler.find_library('atomic', required : false)
dl_dep = compiler.find_library('dl', required : false)

subproject_libdirs = []
subproject_deps = []
subprojects = [['boost', 'boost_1_64_0', '>= 1.64.0', ['system', 'thread']],
               ['wallycore', 'libwally-core', '>= 0.4.0', []],
               ['openssl', 'openssl-1.0.2m', '>= 1.0.2', []]]

foreach sub : subprojects
    subproject_libdirs += join_paths(meson.build_root(), sub[1], 'build', 'lib')
    message('Building ' + sub[0] + '...')
    run_cmd_args = []
    if meson.is_cross_build()
        run_cmd_args += ['--' + meson.get_cross_property('target_os')]
    endif
    res = run_command(join_paths('tools', 'build' + sub[0] + '.sh'), run_cmd_args)
    if res.returncode() != 0
        message('--- Failed to run command (stdout) ---')
        message(res.stdout())
        message('--- Failed to run command (stderr) ---')
        message(res.stderr())
    endif
    subproject_deps += dependency(sub[0], modules : sub[3], version : sub[2], static : true)
endforeach

if build_machine.system() == 'linux'
    subproject_deps += dependency('libsecp256k1', static : true)
endif

# includes
autobahn_inc_dir = join_paths(meson.build_root().split('/')[-1], 'autobahn-cpp')
msgpack_inc_dir = join_paths(meson.build_root().split('/')[-1], 'msgpack', 'include')
websocketpp_inc_dir = join_paths(meson.build_root().split('/')[-1], 'websocketpp-0.7.0')
wallycore_src_dir = join_paths(meson.build_root().split('/')[-1], 'libwally-core', 'src')
sdk_inc_dir = 'src'

incdir = include_directories([autobahn_inc_dir, msgpack_inc_dir, sdk_inc_dir, wallycore_src_dir, websocketpp_inc_dir])

# builds
subdirs = ['src']
foreach n : subdirs
    subdir(n)
endforeach
