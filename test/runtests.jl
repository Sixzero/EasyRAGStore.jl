using Test
using EasyRAGStore

@testset failfast=true "EasyRAGStore Tests" begin
    include("test_compression.jl")
    include("test_rag_store.jl")
    include("test_file_utils.jl")
    include("test_index_logger.jl")
end
;
