tls = get_option('with-tls')
if tls
    add_global_arguments('-DWITH_TLS', language : 'cpp')
endif

executable('wss', 'wss.cpp',
            include_directories : incdir,
            dependencies : [boostdep, ssldep],
            cpp_args : ['-DMSGPACK_DEFAULT_API_VERSION=1', '-Wno-deprecated-declarations'])

