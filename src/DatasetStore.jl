
# Note: The DatasetStore is designed to efficiently store multiple indices in a single file.
# This approach allows for significant compression due to repetitions across indices.
# The `chunks` field is a Dict of Dicts, where each inner Dict represents an chunks.
# This structure enables efficient storage and retrieval of multiple related indices.
# 
# Important: The compress and decompression process may require access to all stored indices,
# as compressed chunks (RefChunks) can reference content in any of the stored indices.
# This cross-chunks referencing is key to achieving high compression ratios.

using OrderedCollections
using EasyContext: AbstractChunk

"""
    DatasetStore

A struct to store collections of indices and their compression strategy.

# Fields
- `chunks::Dict{String, OrderedDict{String, Union{String, RefChunk}}}`: A dictionary of indices, where each chunks is an OrderedDict mapping sources to chunks.
- `compression::CompressionStrategy`: The compression strategy used for storing chunks.
- `cache_dir::String`: The directory where cache files are stored.
"""
@kwdef struct DatasetStore
    chunks::Dict{String, AbstractVector{Union{String, AbstractChunkFormat, AbstractChunk}}} = Dict{String, AbstractVector{Union{String, AbstractChunkFormat, AbstractChunk}}}()
    compression::CompressionStrategy = RefChunkIdxCompression()
    cache_dir::String = joinpath(dirname(@__DIR__), "benchmark_data")
end

"""
    append!(store::DatasetStore, chunks::OrderedDict{String, String})

Append a new chunks to the DatasetStore.

# Arguments
- `store::DatasetStore`: The DatasetStore object to update.
- `chunks::OrderedDict{String, String}`: New chunks to add, where keys are sources and values are chunks.

# Returns
- `String`: The ID of the newly added chunks.
"""
function Base.append!(store::DatasetStore, chunks::AbstractVector{T}) where T
    index_id = fast_cache_key(chunks)
    compressed_index = compress(store.compression, store.chunks, chunks)
    store.chunks[index_id] = compressed_index
    
    save_index_store(joinpath(store.cache_dir, "index_store.jld2"), store)
    
    return index_id
end

"""
    get_index(store::DatasetStore, index_id::String)

Retrieve and decompress an chunks from the DatasetStore.

# Arguments
- `store::DatasetStore`: The DatasetStore object to query.
- `index_id::String`: The ID of the chunks to retrieve.

# Returns
- `OrderedDict{String, String}`: The retrieved chunks with decompressed chunks.
"""
function get_index(store::DatasetStore, index_id::String)
    if haskey(store.chunks, index_id)
        return decompress(store.chunks[index_id], store)
    else
        throw(KeyError("Index $index_id not found in the store"))
    end
end

"""
    save_dataset_store(filename::String, store::DatasetStore)

Save a DatasetStore object to a JLD2 file.

# Arguments
- `filename::String`: The name of the file to save the store to.
- `store::DatasetStore`: The DatasetStore object to save.
"""
function save_dataset_store(filename::String, store::DatasetStore)
    safe_jldsave(filename; chunks=store.chunks, compression=store.compression)
end

"""
    save_index_store(filename::String, store::DatasetStore)

Save the chunks of a DatasetStore object to a JLD2 file.

# Arguments
- `filename::String`: The name of the file to save the chunks to.
- `store::DatasetStore`: The DatasetStore object containing the chunks to save.
"""
function save_index_store(filename::String, store::DatasetStore)
    safe_jldsave(filename; chunks=store.chunks)
end

"""
    load_dataset_store(filename::String) -> DatasetStore

Load a DatasetStore object from a JLD2 file.

# Arguments
- `filename::String`: The name of the file to load the store from.

# Returns
- `DatasetStore`: The loaded DatasetStore object.
"""
function load_dataset_store(filename::String)
    data = load(filename, typemap=Dict(
        "EasyRAGBench.AbstractChunkFormat" => EasyRAGStore.AbstractChunkFormat,
        "EasyRAGBench.RefChunk" => EasyRAGStore.RefChunk,
        "EasyRAGBench.CompressionStrategy" => EasyRAGStore.CompressionStrategy,
        "EasyRAGBench.RefChunkCompression" => EasyRAGStore.RefChunkCompression
    ))
    return DatasetStore(
        chunks = data["chunks"],
        compression = data["compression"],
        cache_dir = dirname(filename)
    )
end

"""
    decompress(chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}, store::DatasetStore)

Decompress an entire chunks using the store's compression method and all available chunks.

# Arguments
- `chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The chunks to decompress.
- `store::DatasetStore`: The DatasetStore containing the compression method and all chunks.

# Returns
- `OrderedDict{String, String}`: The decompressed chunks.
"""
function decompress(chunks::OrderedDict{String, Union{String, T}}, store::DatasetStore) where T <: AbstractChunkFormat
    decompress(store.compression, chunks, store.chunks)
end

compress(c::RefChunkCompression, store::DatasetStore, new_index::OrderedDict{String, String}) = compress(c, store.chunks, new_index)
compress(c::RefChunkIdxCompression, store::DatasetStore, new_index::AbstractVector{T}) where T = compress(c, store.chunks, new_index)

