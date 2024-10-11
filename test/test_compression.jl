using Test
using EasyRAGStore: RefChunkCompression, NoCompression, AbstractChunkFormat
using EasyRAGStore
using OrderedCollections

# Helper function to calculate the size of an index
function calculate_index_size(index::OrderedDict{String, Union{String, T}}) where T <: AbstractChunkFormat
    return sum(sizeof(chunk) for chunk in values(index))
end

# Helper function to count RefChunks
function count_refchunks(index::OrderedDict{String, Union{String, EasyRAGStore.RefChunk}})
    return count(chunk -> chunk isa EasyRAGStore.RefChunk, values(index))
end

# Helper function to count references to each chunk
function count_references(all_indexes)
    ref_count = Dict{String, Int}()
    for (_, index) in all_indexes
        for (_, chunk) in index
            if chunk isa EasyRAGStore.RefChunk
                ref_key = "$(chunk.collection_id):$(chunk.source)"
                ref_count[ref_key] = get(ref_count, ref_key, 0) + 1
            end
        end
    end
    return ref_count
end

@testset "Compression Tests" begin
    @testset "NoCompression" begin
        compression = NoCompression()
        index = OrderedDict("source1" => "content1", "source2" => "content2")
        
        # Test compression (which should be identity for NoCompression)
        compressed = EasyRAGStore.compress(compression, Dict(), index)
        @test compressed == index
        
        # Test decompression (which should be identity for NoCompression)
        decompressed = EasyRAGStore.decompress(compression, compressed, Dict{String,OrderedDict{String,String}}())
        @test decompressed == index
        
        # Check sizes (should be the same for NoCompression)
        @test calculate_index_size(index) == calculate_index_size(compressed)
    end
    
    @testset "RefChunkCompression" begin
        compression = RefChunkCompression()
        
        # Create some test data
        chunk1 = EasyRAGStore.generate_large_content(10, seed=1)  # 10 KB of content
        chunk2 = EasyRAGStore.generate_large_content(10, seed=2)  # Another 10 KB of content
        
        index1 = OrderedDict("source1" => chunk1, "source2" => chunk2)
        index2 = OrderedDict("source3" => chunk1, "source4" => chunk2)
        index3 = OrderedDict("source5" => EasyRAGStore.generate_large_content(10, seed=3))  # Unique content
        
        # Compress the indexes
        compressed1 = EasyRAGStore.compress(compression, Dict(), index1)
        all_indexes = Dict("index1" => compressed1)
        compressed2 = EasyRAGStore.compress(compression, all_indexes, index2)
        all_indexes["index2"] = compressed2
        compressed3 = EasyRAGStore.compress(compression, all_indexes, index3)
        all_indexes["index3"] = compressed3
        
        # Test decompression
        decompressed1 = EasyRAGStore.decompress(compression, compressed1, all_indexes)
        decompressed2 = EasyRAGStore.decompress(compression, compressed2, all_indexes)
        decompressed3 = EasyRAGStore.decompress(compression, compressed3, all_indexes)
        
        @test decompressed1 == index1
        @test decompressed2 == index2
        @test decompressed3 == index3
        
        # Measure compression effectiveness
        original_size = calculate_index_size(index1) + calculate_index_size(index2) + calculate_index_size(index3)
        compressed_size = calculate_index_size(compressed1) + calculate_index_size(compressed2) + calculate_index_size(compressed3)
        compression_ratio = compressed_size / original_size
        
        println("Original size: $original_size bytes")
        println("Compressed size: $compressed_size bytes")
        println("Compression ratio: $(round(compression_ratio, digits=2))")
        
        # Count RefChunks
        total_refchunks = count_refchunks(compressed1) + count_refchunks(compressed2) + count_refchunks(compressed3)
        println("Total RefChunks: $total_refchunks")
        
        # Assertions
        @test compression_ratio < 1.0  # Ensure some compression happened
        @test total_refchunks > 0  # Ensure RefChunks were created
        @test count_refchunks(compressed1) == 0  # First index should have no RefChunks
        @test count_refchunks(compressed2) == 2  # Second index should have all RefChunks
        @test count_refchunks(compressed3) == 0  # Third index should have no RefChunks (unique content)

        # Count references
        ref_count = count_references(all_indexes)
        println("Reference counts: $ref_count")
        
        @test length(ref_count) == 2  # Two chunks should be referenced
        @test all(count -> count == 1, values(ref_count))  # Each referenced chunk should be referenced once
    end
    
    @testset "fast_cache_key" begin
        index = OrderedDict("source1" => "content1", "source2" => "content2")
        @time key = EasyRAGStore.fast_cache_key(index)
        @test typeof(key) == String
        @test length(key) == 16  # Should be a 16-digit hexadecimal string
        
        # Test with empty input
        empty_key = EasyRAGStore.fast_cache_key(OrderedDict{String, String}())
        @test empty_key == "0"
    end
end

