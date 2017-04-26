incdir = include_directories('../autobahn-cpp')

tls = get_option('with-tls')
if tls
    add_global_arguments('-DWITH_TLS', language : 'cpp')
endif

ssldep = dependency('openssl', version : '>= 1.0.2')
boostdep = dependency('boost', modules : ['asio', 'system', 'thread'])

executable('wss', 'wss.cpp',
            include_directories : incdir,
            dependencies : [boostdep, ssldep])

