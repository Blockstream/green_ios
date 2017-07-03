sed = find_program('gsed', 'sed')
swig_target = custom_target('swig',
                     command : [join_paths(meson.source_root(), 'tools', 'swig.sh'),
                                sed, '@BUILD_DIR@/../gasdk_wrap.c', '@BUILD_DIR@/..', '@INPUT@'],
                     input : 'swig_gasdk.i',
                     output : ['gasdk_wrap.c'])

java_inc_dir = include_directories(join_paths(java_home, 'include'),
                                   join_paths(java_home, 'include', build_machine.system()))
libswig_java = shared_module('swig_java', swig_target,
                              include_directories : java_inc_dir,
                              dependencies : dependencies,
                              link_with : libga)
