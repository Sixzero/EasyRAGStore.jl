
"""
    TestcaseStore

A struct to store questions/test cases associated with indices.

# Fields
- `index_to_cases::Dict{String, Vector{NamedTuple}}`: A dictionary mapping index IDs to their associated test cases. Each test case is a NamedTuple containing at least (:question, :answer) and optionally :timestamp.
- `cache_dir::String`: The directory where cache files are stored.
"""
@kwdef struct TestcaseStore
    index_to_cases::Dict{String, Vector{NamedTuple}} = Dict()
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
    if !haskey(store.index_to_cases, index_id)
        store.index_to_cases[index_id] = NamedTuple[]
    end
    push!(store.index_to_cases[index_id], question)
    
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
    if haskey(store.index_to_cases, index_id)
        return store.index_to_cases[index_id]
    else
        return NamedTuple[]
    end
end

"""
    save_testcase_store(filename::String, store::TestcaseStore)

Save a TestcaseStore object to a JLD2 file.
"""
function save_testcase_store(filename::String, store::TestcaseStore)
    safe_jldsave(filename; index_to_cases=store.index_to_cases)
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
    # Support both new and legacy keys
    cases = if haskey(data, "index_to_cases")
        data["index_to_cases"]
    elseif haskey(data, "questions")  # legacy key
        data["questions"]
    else
        Dict{String, Vector{NamedTuple}}()
    end
    
    return TestcaseStore(
        index_to_cases = cases,
        cache_dir = dirname(filename)
    )
end

"""
    update_last_question!(store::TestcaseStore, index_id::String, updated_question::NamedTuple)

Update the last question for a given index_id with new data.
"""
function update_last_question!(store::TestcaseStore, index_id::String, updated_question::NamedTuple)
    if haskey(store.index_to_cases, index_id) && !isempty(store.index_to_cases[index_id])
        store.index_to_cases[index_id][end] = updated_question
        save_testcase_store(joinpath(store.cache_dir, "testcase_store.jld2"), store)
    end
end
