using Base.Threads: ReentrantLock, @spawn
using JLD2
using BoilerplateCvikli: @async_showerr

include("DatasetStore.jl")
include("TestcaseStore.jl")
include("FileUtils.jl")

"""
    RAGStore

A struct to manage both DatasetStore and TestcaseStore.

# Fields
- `filename::String`: The base name of the files to save/load the store.
- `cache_dir::String`: The directory where cache files are stored.
- `dataset_store::Union{Task, DatasetStore}`: The DatasetStore object for managing indices.
- `testcase_store::Union{Task, TestcaseStore}`: The TestcaseStore object for managing questions/test cases.
- `lock::ReentrantLock`: Lock for thread safety.
"""
mutable struct RAGStore
    filename::String
    cache_dir::String
    dataset_store::Union{Task, DatasetStore}  
    testcase_store::Union{Task, TestcaseStore}
    lock::ReentrantLock
end

function RAGStore(filename::String, cache_dir::String = joinpath(dirname(@__DIR__), "benchmark_data"))
    dataset_file = joinpath(cache_dir, "$(filename)_dataset.jld2")
    testcase_file = joinpath(cache_dir, "$(filename)_testcase.jld2")
    
    if isfile(dataset_file) && isfile(testcase_file)
        # Start async loading
        dataset_task = @spawn load_dataset_store(dataset_file)
        testcase_task = @spawn load_testcase_store(testcase_file)
        return RAGStore(filename, cache_dir, dataset_task, testcase_task, ReentrantLock())
    end
    return RAGStore(filename, cache_dir, DatasetStore(), TestcaseStore(), ReentrantLock())
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
    @async_showerr lock(store.lock) do
        ensure_loaded!(store)
        index_id = append!(store.dataset_store, index)
        
        # Check if the question already exists for this index_id
        existing_questions = get_questions(store.testcase_store, index_id)
        if !any(q -> q == question, existing_questions)
            append!(store.testcase_store, index_id, question)
            save_store(store)  # Save the store after appending
        end
        
        index_id
    end
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
    lock(store.lock) do
        ensure_loaded!(store)
        get_index(store.dataset_store, index_id)
    end
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
    lock(store.lock) do
        ensure_loaded!(store)
        get_questions(store.testcase_store, index_id)
    end
end

"""
    save_store(store::RAGStore)

Save a Store object to JLD2 files.

# Arguments
- `store::RAGStore`: The RAGStore object to save.
"""
function save_store(store::RAGStore)
    lock(store.lock) do
        ensure_loaded!(store)
        dataset_filename = joinpath(store.cache_dir, "$(store.filename)_dataset.jld2")
        testcase_filename = joinpath(store.cache_dir, "$(store.filename)_testcase.jld2")
        save_dataset_store(dataset_filename, store.dataset_store)
        save_testcase_store(testcase_filename, store.testcase_store)
    end
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

# Helper to ensure we have loaded store
function ensure_loaded!(store::Task) fetch(store) end
function ensure_loaded!(store::RAGStore)
    lock(store.lock) do
        if store.dataset_store isa Task
            store.dataset_store = fetch(store.dataset_store)
        end
        if store.testcase_store isa Task
            store.testcase_store = fetch(store.testcase_store)
        end
    end
end
function ensure_loaded!(store) store end

export RAGStore
