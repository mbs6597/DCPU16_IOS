:kernel_bss_start

:pid_alloc

org (pid_alloc+32)
:pid_procs

org (pid_procs+32)
:pid_loader

org (pid_loader+32)
:pid_init


org (pid_init+32)

:alloc_map_start

org (alloc_map_start+256)
:alloc_map_end


org (alloc_map_end+8)
:initstack

org (initstack+8)
:loaderstack

org (loaderstack+8)
:procsstack


org (procsstack+8)
:allocstack

:kernel_bss_end