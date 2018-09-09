c_cpp_sources = [
    'green-cli.c'
]

if clang_format.found()
    custom_target('examples-clang-format', input : c_cpp_sources, output : 'clang-format', command : [clang_format, '-i', '@INPUT@'])
endif

link_depends = []
link_whole = [libtests_common]
if host_machine.cpu_family().contains('iphone')
    link_depends += [archiver]
else
    link_whole += [libga.get_static_lib()]
endif

foreach source : c_cpp_sources
    exe_name = source.split('.')[0]
    exe_sources = [source]
    exe = executable(exe_name,
                     exe_sources,
                     c_args : executable_c_cpp_args,
                     cpp_args : executable_c_cpp_args,
                     link_args : executable_link_args,
                     link_whole : link_whole,
                     link_depends : link_depends,
                     include_directories : incdir,
                     dependencies : [threads_dep, libga_dep],
                     install: true)
endforeach
