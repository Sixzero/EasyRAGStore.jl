
"""
    TestcaseStore

A struct to store questions/test cases associated with indices.

# Fields
- `questions::Dict{String, Vector{NamedTuple}}`: A dictionary mapping index IDs to their associated questions and other metadata as a Vector of NamedTuples.
- `cache_dir::String`: The directory where cache files are stored.
"""
@kwdef struct TestcaseStore
    questions::Dict{String, Vector{NamedTuple}} = Dict()
    cache_dir::String = joinpath(dirname(@__DIR__), "benchmark_data")
end

"""
    append!(store::TestcaseStore, index_id::String, question::NamedTuple; metadata::Dict{String, Any} = Dict())

Append a new question/test case to the TestcaseStore.

# Arguments
- `store::TestcaseStore`: The TestcaseStore object to update.
- `index_id::String`: The ID of the index associated with this question.
- `question::NamedTuple`: The question and other metadata associated with this index.
- `metadata::Dict{String, Any}`: Additional metadata to store with the question.

# Returns
- `Nothing`
"""
function Base.append!(store::TestcaseStore, index_id::String, question::NamedTuple)
    if !haskey(store.questions, index_id)
        store.questions[index_id] = NamedTuple[]
    end
    push!(store.questions[index_id], question)
    
    save_testcase_store(joinpath(store.cache_dir, "testcase_store.jld2"), store)
end

"""
    get_questions(store::TestcaseStore, index_id::String) -> Vector{NamedTuple}

Retrieve questions and metadata associated with a specific index.

# Arguments
- `store::TestcaseStore`: The TestcaseStore object to query.
- `index_id::String`: The ID of the index to retrieve questions for.

# Returns
- `Vector{NamedTuple}`: A vector of NamedTuples containing questions and other metadata associated with the index.
"""
function get_questions(store::TestcaseStore, index_id::String)
    if haskey(store.questions, index_id)
        return store.questions[index_id]
    else
        return NamedTuple[]
    end
end

"""
    save_testcase_store(filename::String, store::TestcaseStore)

Save a TestcaseStore object to a JLD2 file.

# Arguments
- `filename::String`: The name of the file to save the store to.
- `store::TestcaseStore`: The TestcaseStore object to save.
"""
function save_testcase_store(filename::String, store::TestcaseStore)
    jldsave(filename; questions=store.questions)
end


"""
    load_testcase_store(filename::String) -> TestcaseStore

Load a TestcaseStore object from a JLD2 file.

# Arguments
- `filename::String`: The name of the file to load the store from.

# Returns
- `TestcaseStore`: The loaded TestcaseStore object.
"""
function load_testcase_store(filename::String)
    data = load(filename)
    return TestcaseStore(
        questions = data["questions"],
        cache_dir = dirname(filename)
    )
end
