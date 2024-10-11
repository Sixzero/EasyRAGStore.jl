
# Note: The DatasetStore is designed to efficiently store multiple indices in a single file.
# This approach allows for significant compression due to repetitions across indices.
# The `indexes` field is a Dict of Dicts, where each inner Dict represents an index.
# This structure enables efficient storage and retrieval of multiple related indices.
# 
# Important: The compress and decompression process may require access to all stored indices,
# as compressed chunks (RefChunks) can reference content in any of the stored indices.
# This cross-index referencing is key to achieving high compression ratios.

using OrderedCollections

"""
    DatasetStore

A struct to store collections of indices and their compression strategy.

# Fields
- `indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: A dictionary of indices, where each index is an OrderedDict mapping sources to chunks.
- `compression::CompressionStrategy`: The compression strategy used for storing chunks.
- `cache_dir::String`: The directory where cache files are stored.
"""
@kwdef struct DatasetStore
    indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}} = Dict()
    compression::CompressionStrategy = RefChunkCompression()
    cache_dir::String = joinpath(dirname(@__DIR__), "benchmark_data")
end

"""
    append!(store::DatasetStore, index::OrderedDict{String, String})

Append a new index to the DatasetStore.

# Arguments
- `store::DatasetStore`: The DatasetStore object to update.
- `index::OrderedDict{String, String}`: New index to add, where keys are sources and values are chunks.

# Returns
- `String`: The ID of the newly added index.
"""
function Base.append!(store::DatasetStore, index::OrderedDict{String, String})
    index_id = fast_cache_key(index)
    compressed_index = compress(store.compression, store.indexes, index)
    store.indexes[index_id] = compressed_index
    
    save_index_store(joinpath(store.cache_dir, "index_store.jld2"), store)
    
    return index_id
end
"""
    get_index(store::DatasetStore, index_id::String)

Retrieve and decompress an index from the DatasetStore.

# Arguments
- `store::DatasetStore`: The DatasetStore object to query.
- `index_id::String`: The ID of the index to retrieve.

# Returns
- `OrderedDict{String, String}`: The retrieved index with decompressed chunks.
"""
function get_index(store::DatasetStore, index_id::String)
    if haskey(store.indexes, index_id)
        return decompress(store.indexes[index_id], store)
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
    jldsave(filename; indexes=store.indexes, compression=store.compression)
end

"""
    save_index_store(filename::String, store::DatasetStore)

Save the indexes of a DatasetStore object to a JLD2 file.

# Arguments
- `filename::String`: The name of the file to save the indexes to.
- `store::DatasetStore`: The DatasetStore object containing the indexes to save.
"""
function save_index_store(filename::String, store::DatasetStore)
    jldsave(filename; indexes=store.indexes)
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
    data = load(filename)
    return DatasetStore(
        indexes = data["indexes"],
        compression = data["compression"],
        cache_dir = dirname(filename)
    )
end

"""
    decompress(index::OrderedDict{String, Union{String, AbstractChunkFormat}}, store::DatasetStore)

Decompress an entire index using the store's compression method and all available indexes.

# Arguments
- `index::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The index to decompress.
- `store::DatasetStore`: The DatasetStore containing the compression method and all indexes.

# Returns
- `OrderedDict{String, String}`: The decompressed index.
"""
function decompress(index::OrderedDict{String, Union{String, AbstractChunkFormat}}, store::DatasetStore)
    decompress(store.compression, index, store.indexes)
end

compress(c::RefChunkCompression, store::DatasetStore, new_index::OrderedDict{String, String}) = compress(c, store.indexes, new_index)

