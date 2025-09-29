function(soong_config_variable out_var a b)
    if(a STREQUAL "ANDROID" AND b STREQUAL "release_crashrecovery_module")
        set(${out_var} "true" PARENT_SCOPE)
    endif()
endfunction(soong_config_variable)

function(release_flag)
endfunction(release_flag)

function(product_variable out_var key)
    if(key STREQUAL "build_from_text_stub")
        set(${out_var} TRUE PARENT_SCOPE)
    endif()
endfunction()