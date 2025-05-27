using Random
using EasyContext: get_source, AbstractChunk, fast_cache_key

# Abstract type for compression strategies
abstract type CompressionStrategy end
abstract type AbstractChunkFormat end

# Concrete types for different compression strategies
struct NoCompression <: CompressionStrategy end
struct RefChunkCompression <: CompressionStrategy end
struct RefChunkIdxCompression <: CompressionStrategy end

# RefChunk to store references to other chunks
struct RefChunk <: AbstractChunkFormat
    collection_id::String
    source::String
end# RefChunk to store references to other chunks
struct RefChunkIdx <: AbstractChunkFormat
    idx::String
    source::String
end

# Generate a large, non-repetitive content (kept for testing purposes)
function generate_large_content(size_kb::Int; seed=42)
    Random.seed!(seed)
    chars = ['a':'z'..., 'A':'Z'..., '0':'9'..., ' ', '.', ',', '!', '?', '-', ':', ';', '(', ')', '\n']
    content = String(rand(chars, size_kb * 1024))
    return content
end


"""
    compress(::RefChunkCompression, chunk_store::Dict, new_index::OrderedDict{String, String}) -> OrderedDict{String, Union{String, RefChunk}}

Compress a new chunks against the existing indices using RefChunkCompression.
This function checks for existing chunks across all stored indices and creates RefChunks where possible.

# Arguments
- `::RefChunkCompression`: The compression strategy (dispatch on this type)
- `chunk_store::Dict`: The existing chunk_store
- `new_index::OrderedDict{String, String}`: The new chunks to be compressed

# Returns
- `OrderedDict{String, Union{String, RefChunk}}`: The compressed chunks
"""
function compress(::RefChunkCompression, chunk_store::Dict{String, AbstractVector{T}}, new_index::AbstractVector{Union{T, RefChunk}}) where T
    compressed_index = Vector{String, Union{String, T, RefChunk}}()
    
    # Generate a cache key for the new chunks and check for existence!
    new_index_key = fast_cache_key(new_index)
    if haskey(chunk_store, new_index_key)
        return chunk_store[new_index_key]
    end
    
    for (source, chunk) in new_index
        ref_found = false
        
        # Check all existing indices for matching chunks
        for (existing_id, existing_index) in chunk_store
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

"""
    compress(::RefChunkIdxCompression, chunk_store::Dict, new_index::AbstractVector{T}) where T

Compress a new chunks against the existing indices using RefChunkIdxCompression.
This function checks for existing chunks across all stored indices and creates RefChunkIdx where possible.
"""
function compress(::RefChunkIdxCompression, chunk_store::Dict{String, AbstractVector{T}}, new_index::AbstractVector{T2}) where {T, T2}
    compressed_index = Vector{Union{T2, RefChunkIdx}}()
    
    # Generate a cache key for the new chunks and check for existence
    new_index_key = fast_cache_key(new_index)
    if haskey(chunk_store, new_index_key)
        return chunk_store[new_index_key]
    end
    
    # Create a flat lookup of all chunks for faster search
    chunk_lookup = Dict{String,Tuple{String,Int}}()
    for (collection_id, chunks) in chunk_store
        for (i, chunk) in enumerate(chunks)
            chunk_str = string(chunk)
            if !haskey(chunk_lookup, chunk_str)
                chunk_lookup[chunk_str] = (collection_id, i)
            end
        end
    end
    
    # Process new chunks
    for chunk in new_index
        chunk_str = string(chunk)
        if haskey(chunk_lookup, chunk_str)
            collection_id, idx = chunk_lookup[chunk_str]
            push!(compressed_index, RefChunkIdx(string(idx), collection_id))
        else
            push!(compressed_index, chunk)
        end
    end
    
    return compressed_index
end

# Add a method for NoCompression as well for consistency
function compress(::NoCompression, chunk_store::AbstractDict{String, AbstractVector{T}}, new_index::AbstractVector{T}) where T
    return new_index
end

"""
    decompress(::NoCompression, chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}, chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress an chunks when no compression is used (identity operation).

# Arguments
- `::NoCompression`: The compression strategy (no compression).
- `chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The chunks to decompress.
- `chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored chunk_store (not used for NoCompression).

# Returns
- `OrderedDict{String, String}`: The decompressed chunks (identical to input for NoCompression).
"""
function decompress(::NoCompression, chunks::AbstractVector{T}, chunk_store::Dict{String, AbstractVector{T}}) where T
    return chunks
end

"""
    decompress(::RefChunkCompression, chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}, chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress an chunks using RefChunkCompression, resolving all RefChunks to their original content.

# Arguments
- `::RefChunkCompression`: The compression strategy (RefChunkCompression).
- `chunks::OrderedDict{String, Union{String, AbstractChunkFormat}}`: The chunks to decompress.
- `chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored chunk_store for resolving RefChunks.

# Returns
- `OrderedDict{String, String}`: The fully decompressed chunks.
"""
function decompress(::RefChunkCompression, chunks::AbstractVector{T}, chunk_store::Dict{String, AbstractVector{T2}}) where {T, T2}
    decompressed = OrderedDict{String, String}()
    for (source, chunk) in chunks
        decompressed[source] = decompress_chunk(chunk, chunk_store)
    end
    return decompressed
end

"""
    decompress(::RefChunkIdxCompression, chunks::AbstractVector{T}, chunk_store::Dict{String, AbstractVector{T}}) where T

Decompress chunks using RefChunkIdxCompression, resolving all RefChunkIdx to their original content.
"""
function decompress(::RefChunkIdxCompression, chunks::AbstractVector{T}, chunk_store::Dict{String, AbstractVector{T}}) where T
    decompressed = similar(chunks, T)
    for (i, chunk) in enumerate(chunks)
        decompressed[i] = decompress_chunk(chunk, chunk_store)
    end
    return decompressed
end

"""
    decompress_chunk(chunk::Union{String, RefChunk}, chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}})

Decompress a single chunk, handling both raw strings and RefChunks.

# Arguments
- `chunk::Union{String, RefChunk}`: The chunk to decompress.
- `chunk_store::Dict{String, OrderedDict{String, Union{String, AbstractChunkFormat}}}`: All stored chunk_store for resolving RefChunks.

# Returns
- `String`: The decompressed content.
"""
function decompress_chunk(chunk::String, chunk_store::AbstractDict{String, AbstractVector{T}}) where T
    return chunk
end
function decompress_chunk(chunk::AbstractChunk, chunk_store::AbstractDict{String, AbstractVector{T}}) where T
    return chunk
end

function decompress_chunk(chunk::RefChunk, chunk_store::AbstractDict{String, AbstractVector{T}}) where T
    referenced_chunks = chunk_store[chunk.collection_id]
    referenced_chunk = referenced_chunks[chunk.source]
    return referenced_chunk
end

# Add decompress_chunk for RefChunkIdx
function decompress_chunk(chunk::RefChunkIdx, chunk_store::AbstractDict{String, AbstractVector{T}}) where T
    referenced_chunks = chunk_store[chunk.source]
    idx = parse(Int, chunk.idx)
    referenced_chunk = referenced_chunks[idx]
    return referenced_chunk
end

