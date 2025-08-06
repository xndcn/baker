function(soong_config_variable)
endfunction(soong_config_variable)

function(release_flag)
endfunction(release_flag)

function(product_variable out_var key)
    if(key STREQUAL "build_from_text_stub")
        set(${out_var} TRUE PARENT_SCOPE)
    endif()
endfunction()