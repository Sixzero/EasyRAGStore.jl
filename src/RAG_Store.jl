export RAGStore

using JLD2

include("DatasetStore.jl")
include("TestcaseStore.jl")

"""
    RAGStore

A struct to manage both DatasetStore and TestcaseStore.

# Fields
- `filename::String`: The base name of the files to save/load the store.
- `cache_dir::String`: The directory where cache files are stored.
- `dataset_store::DatasetStore`: The DatasetStore object for managing indices.
- `testcase_store::TestcaseStore`: The TestcaseStore object for managing questions/test cases.
"""
struct RAGStore
    filename::String
    cache_dir::String
    dataset_store::DatasetStore 
    testcase_store::TestcaseStore 
end

function RAGStore(filename::String, cache_dir::String = joinpath(dirname(@__DIR__), "benchmark_data"))
    dataset_file = joinpath(cache_dir, "$(filename)_dataset.jld2")
    testcase_file = joinpath(cache_dir, "$(filename)_testcase.jld2")
    
    if isfile(dataset_file) && isfile(testcase_file)
        return load_store(cache_dir, filename)
    end
    return RAGStore(filename, cache_dir, DatasetStore(), TestcaseStore())
end

"""
    append!(store::RAGStore, index::OrderedDict{String, String}, question::NamedTuple; metadata::Dict{String, Any} = Dict())

Append a new index and its associated question/test case to the store.

# Arguments
- `store::RAGStore`: The RAGStore object to update.
- `index::OrderedDict{String, String}`: New index to add, where keys are sources and values are chunks.
- `question::NamedTuple`: The question and other metadata associated with this index.
- `metadata::Dict{String, Any}`: Additional metadata to store with the question.

# Returns
- `String`: The ID of the newly added index.
"""
function Base.append!(store::RAGStore, index::OrderedDict{String, String}, question::NamedTuple)
    index_id = append!(store.dataset_store, index)
    append!(store.testcase_store, index_id, question)
    save_store(store)  # Save the store after appending
    return index_id
end

"""
    get_index(store::RAGStore, index_id::String)

Retrieve an index from the store.

# Arguments
- `store::RAGStore`: The RAGStore object to query.
- `index_id::String`: The ID of the index to retrieve.

# Returns
- `OrderedDict{String, String}`: The retrieved index with decompressed chunks.
"""
function get_index(store::RAGStore, index_id::String)
    return get_index(store.dataset_store, index_id)
end

"""
    get_questions(store::RAGStore, index_id::String) -> Vector{NamedTuple}

Retrieve questions and metadata associated with a specific index.

# Arguments
- `store::RAGStore`: The RAGStore object to query.
- `index_id::String`: The ID of the index to retrieve questions for.

# Returns
- `Vector{NamedTuple}`: A vector of NamedTuples containing questions and other metadata associated with the index.
"""
function get_questions(store::RAGStore, index_id::String)
    return get_questions(store.testcase_store, index_id)
end

"""
    save_store(store::RAGStore)

Save a Store object to JLD2 files.

# Arguments
- `store::RAGStore`: The RAGStore object to save.
"""
function save_store(store::RAGStore)
    dataset_filename = joinpath(store.cache_dir, "$(store.filename)_dataset.jld2")
    testcase_filename = joinpath(store.cache_dir, "$(store.filename)_testcase.jld2")
    save_dataset_store(dataset_filename, store.dataset_store)
    save_testcase_store(testcase_filename, store.testcase_store)
end

"""
    load_store(cache_dir::String, filename::String) -> RAGStore

Load a RAGStore object from JLD2 files.

# Arguments
- `filename::String`: The base name of the files to load the store from.
- `cache_dir::String`: The directory where cache files are stored.

# Returns
- `RAGStore`: The loaded RAGStore object.
"""
function load_store(cache_dir::String, filename::String)
    dataset_filename = joinpath(cache_dir, "$(filename)_dataset.jld2")
    testcase_filename = joinpath(cache_dir, "$(filename)_testcase.jld2")
    dataset_store = load_dataset_store(dataset_filename)
    testcase_store = load_testcase_store(testcase_filename)
    return RAGStore(filename, cache_dir, dataset_store, testcase_store)
end

# Helper function to ensure cache directory exists
function ensure_cache_dir(store::RAGStore)
    mkpath(store.cache_dir)
end

# Call this function when creating a new RAGStore
function initialize_store(store::RAGStore)
    ensure_cache_dir(store)
    initialize_dataset_store(store.dataset_store)
    initialize_testcase_store(store.testcase_store)
end


