using OrderedCollections: OrderedDict
using Dates


"""
    IndexLogger(store_path::String)

Create an IndexLogger to persistently store and track RAG chunks queries and their associated questions.

The IndexLogger uses lazy initialization for the underlying RAGStore to optimize resource usage. The store is 
only created or loaded when actually needed.

# Arguments
- `store_path::String`: The path where the RAGStore will be saved.

# Example
```julia
logger = IndexLogger("my_rag_logs")
log_index(logger, chunks, "What is the best way to implement RAG?")
```
"""
mutable struct IndexLogger
    store_path::String
    _store::Union{Nothing, RAGStore}
    
    IndexLogger(store_path::String) = new(store_path, nothing)
end

# Helper struct for JLD2 serialization to prevent redundant store serialization
# This avoids saving the expensive cache data of the RAGStore when the IndexLogger is serialized,
# as the store already handles its own persistence.
struct IndexLogger_JLD2
    store_path::String
end

JLD2.writeas(::Type{<:IndexLogger}) = IndexLogger_JLD2
JLD2.readas(::Type{<:IndexLogger_JLD2}) = IndexLogger

Base.convert(::Type{IndexLogger_JLD2}, x::IndexLogger) = IndexLogger_JLD2(x.store_path)
Base.convert(::Type{IndexLogger}, x::IndexLogger_JLD2) = IndexLogger(x.store_path)


# Lazy initialization of store
function ensure_store!(logger::IndexLogger)
    if isnothing(logger._store)
        logger._store = RAGStore(logger.store_path)
        ensure_loaded!(logger._store)
    end
    logger._store
end

function log_index(logger::IndexLogger, chunks::Nothing, question::String; answer=nothing)
    nothing # nothing to log.
end

# TODO adding locks and @async_showerr would be cool here IMO. 
function log_index(logger::IndexLogger, chunks::Vector, question::String; answer=nothing)
    store = ensure_store!(logger)
    case = (; question, timestamp=Dates.now(), returned_answer=answer)
    append!(store, chunks, case)
end

"""
    get_index_log(store::RAGStore) -> Vector{NamedTuple}

Get all logged indices from a RAGStore as a flat vector of NamedTuples.
"""
function get_index_log(store::RAGStore)
    ensure_loaded!(store)
    log_entries = NamedTuple[]
    
    # Iterate through all indices and their questions
    for (index_id, questions) in store.testcase_store.index_to_cases
        for question in questions
            # Merge the index_id into each question entry
            entry = merge(question, (index_id=index_id,))
            push!(log_entries, entry)
        end
    end
    
    # Sort by timestamp if available
    if !isempty(log_entries) && haskey(first(log_entries), :timestamp)
        sort!(log_entries, by=x->x.timestamp)
    end
    
    return log_entries
end

"""
    get_logged_indices(logger::IndexLogger; start_date::DateTime=DateTime(0), end_date::DateTime=Dates.now(), 
                       question_filter::Union{String, Function}=x->true)

Retrieve logged indices from the IndexLogger's RAGStore, optionally filtered by date range and question content.

# Arguments
- `logger::IndexLogger`: The IndexLogger instance to query.
- `start_date::DateTime`: The start date for filtering (inclusive). Default is the beginning of time.
- `end_date::DateTime`: The end date for filtering (inclusive). Default is the current date and time.
- `question_filter::Union{String, Function}`: A string to search for in questions or a function that takes a question string and returns a boolean. Default is to include all questions.

# Returns
- `Vector{NamedTuple}`: A vector of NamedTuples containing index_id, question, and timestamp for each logged chunks.
"""
function get_logged_indices(logger::IndexLogger; start_date::DateTime=DateTime(0), end_date::DateTime=Dates.now(), 
                            question_filter::Union{String, Function}=x->true)
    store = ensure_store!(logger)
    log = get_index_log(store)
    
    filtered_log = filter(log) do entry
        date_match = start_date <= entry.timestamp <= end_date
        question_match = if question_filter isa String
            occursin(question_filter, entry.question)
        else
            question_filter(entry.question)
        end
        date_match && question_match
    end
    
    return filtered_log
end

"""
    ensure_saved(logger::IndexLogger)

Ensure all pending writes to the store are completed.
"""
function ensure_saved(logger::IndexLogger)
    isnothing(logger._store) && return
    ensure_saved(logger._store)
end
