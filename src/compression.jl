using Random

# Abstract type for compression strategies
abstract type CompressionStrategy end
abstract type AbstractChunkFormat end

# Concrete types for different compression strategies
struct NoCompression <: CompressionStrategy end
struct RefChunkCompression <: CompressionStrategy end

# RefChunk to store references to other chunks
struct RefChunk <: AbstractChunkFormat
    collection_id::String
    source::String
end

# Generate a large, non-repetitive content (kept for testing purposes)
function generate_large_content(size_kb::Int; seed=42)
    Random.seed!(seed)
    chars = ['a':'z'..., 'A':'Z'..., '0':'9'..., ' ', '.', ',', '!', '?', '-', ':', ';', '(', ')', '\n']
    content = String(rand(chars, size_kb * 1024))
    return content
end

# Utility functions for generating cache keys
function fast_cache_key(chunks::OrderedDict{String, String})
    fast_cache_key(keys(chunks))
end

function fast_cache_key(keys::AbstractSet)
    if isempty(keys)
        return string(zero(UInt64))  # Return a zero hash for empty input
    end
    
    # Combine hashes of all keys
    combined_hash = reduce(xor, hash(key) for key in keys)
    
    return string(combined_hash, base=16, pad=16)  # Convert to 16-digit hexadecimal string
end

function fast_cache_key(fn::Function, keys)
    if isempty(keys)
        return string(zero(UInt64))  # Return a zero hash for empty input
    end

    # Combine hashes of all keys
    combined_hash = reduce(xor, hash(fn(key)) for key in keys)

    return string(combined_hash, base=16, pad=16)
end

"""
    compress(::RefChunkCompression, indexes::Dict, new_index::OrderedDict{String, String}) -> OrderedDict{String, Union{String, RefChunk}}

Compress a new index against the existing indices using RefChunkCompression.
This function checks for existing chunks across all stored indices and creates RefChunks where possible.

# Arguments
- `::RefChunkCompression`: The compression strategy (dispatch on this type)
- `indexes::Dict`: The existing indexes
- `new_index::OrderedDict{String, String}`: The new index to be compressed

# Returns
- `OrderedDict{String, Union{String, RefChunk}}`: The compressed index
"""
function compress(::RefChunkCompression, indexes::Dict, new_index::OrderedDict{String, String})
    compressed_index = OrderedDict{String, Union{String, RefChunk}}()
    
    # Generate a cache key for the new index and check for existence!
    new_index_key = fast_cache_key(new_index)
    if haskey(indexes, new_index_key)
        return indexes[new_index_key]
    end
    
    for (source, chunk) in new_index
        ref_found = false
        
        # Check all existing indices for matching chunks
        for (existing_id, existing_index) in indexes
            for (existing_source, existing_chunk) in existing_index
                if existing_chunk isa String && existing_chunk == chunk
                    # Create a RefChunk if a match is found
                    compressed_index[source] = RefChunk(existing_id, existing_source)
                    ref_found = true
                    break
                end
            end
            ref_found && break
        end
        
        # If no matching chunk was found, store the original chunk
        if !ref_found
            compressed_index[source] = chunk
        end
    end
    
    return compressed_index
end

# Add a method for NoCompression as well for consistency
function compress(::NoCompression, indexes::Dict, new_index::OrderedDict{String, String})
    return new_index
end

"""
    decompress(::NoCompression, index::OrderedDict{String, Union{String, AbstractChunkFormat}}, all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress an index when no compression is used (identity operation).

# Arguments
- `::NoCompression`: The compression strategy (no compression).
- `index::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The index to decompress.
- `all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored indexes (not used for NoCompression).

# Returns
- `OrderedDict{String, String}`: The decompressed index (identical to input for NoCompression).
"""
function decompress(::NoCompression, index::OrderedDict{String, Union{String, T}}, all_indexes::Dict{String, OrderedDict{String, Union{String, T}}}) where T <: AbstractChunkFormat
    return OrderedDict{String, String}(source => chunk for (source, chunk) in index)
end

"""
    decompress(::RefChunkCompression, index::OrderedDict{String, Union{String, AbstractChunkFormat}}, all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress an index using RefChunkCompression, resolving all RefChunks to their original content.

# Arguments
- `::RefChunkCompression`: The compression strategy (RefChunkCompression).
- `index::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The index to decompress.
- `all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored indexes for resolving RefChunks.

# Returns
- `OrderedDict{String, String}`: The fully decompressed index.
"""
function decompress(::RefChunkCompression, index::OrderedDict{String, Union{String, T}}, all_indexes::Dict{String, OrderedDict{String, Union{String, T}}}) where {T <: AbstractChunkFormat}
    decompressed = OrderedDict{String, String}()
    for (source, chunk) in index
        decompressed[source] = decompress_chunk(chunk, all_indexes)
    end
    return decompressed
end

"""
    decompress_chunk(chunk::Union{String, RefChunk}, all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress a single chunk, handling both raw strings and RefChunks.

# Arguments
- `chunk::Union{String, RefChunk}`: The chunk to decompress.
- `all_indexes::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored indexes for resolving RefChunks.

# Returns
- `String`: The decompressed content.
"""
function decompress_chunk(chunk::String, all_indexes::Dict{String, OrderedDict{String, Union{String, T}}}) where T <: AbstractChunkFormat
    return chunk
end

function decompress_chunk(chunk::RefChunk, all_indexes::Dict{String, OrderedDict{String, Union{String, T}}}) where T <: AbstractChunkFormat
    referenced_index = all_indexes[chunk.collection_id]
    referenced_chunk = referenced_index[chunk.source]
    return decompress_chunk(referenced_chunk, all_indexes)
end

