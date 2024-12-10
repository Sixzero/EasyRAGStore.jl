
"""
    safe_jldsave(filename::String; kwargs...)

Safely save data to a JLD2 file by first writing to a temporary file.
"""
function safe_jldsave(filename::String; kwargs...)
    temp_file = filename * ".tmp"
    try
        jldsave(temp_file; kwargs...)
        mv(temp_file, filename, force=true)
    catch e
        isfile(temp_file) && rm(temp_file)
        rethrow(e)
    end
end
