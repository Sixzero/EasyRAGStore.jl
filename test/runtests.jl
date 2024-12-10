using Test
using EasyRAGStore

@testset "EasyRAGStore Tests" begin
    include("test_compression.jl")
    include("test_rag_store.jl")
    include("test_file_utils.jl")
end
;
