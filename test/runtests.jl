using Test
using EasyRAGBench

@testset "EasyRAGBench Tests" begin
    include("test_compression.jl")
    include("test_rag_store.jl")
end
;
