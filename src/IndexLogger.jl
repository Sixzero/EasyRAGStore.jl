using EasyRAGStore: RAGStore, append!
using OrderedCollections: OrderedDict
using Dates
using PromptingTools.Experimental.RAGTools: AbstractChunkIndex

"""
    IndexLogger(store_path::String)

Create an IndexLogger to persistently store and track RAG index queries and their associated questions.

The IndexLogger uses lazy initialization for the underlying RAGStore to optimize resource usage. The store is 
only created or loaded when actually needed.

# Arguments
- `store_path::String`: The path where the RAGStore will be saved.

# Example
```julia
logger = IndexLogger("my_rag_logs")
log_index(logger, index, "What is the best way to implement RAG?")
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
    end
    logger._store
end

function log_index(logger::IndexLogger, index::Vector{<:AbstractChunkIndex}, question::String)
    log_index(logger, first(index), question)
end

function log_index(logger::IndexLogger, index::AbstractChunkIndex, question::String)
    store = ensure_store!(logger)
    index_dict = OrderedDict(zip(index.sources, index.chunks))
    question_tuple = (question=question, timestamp=Dates.now())
    append!(store, index_dict, question_tuple)
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
- `Vector{NamedTuple}`: A vector of NamedTuples containing index_id, question, and timestamp for each logged index.
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
