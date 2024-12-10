using Test
using EasyRAGStore: safe_jldsave
using JLD2

@testset "FileUtils Tests" begin
    @testset "safe_jldsave" begin
        test_file = tempname() * ".jld2"
        test_data = Dict("test" => "data")

        # Test normal save
        @test_nowarn safe_jldsave(test_file, test_data)
        @test isfile(test_file)
        @test load(test_file)["test"] == "data"

        # Cleanup
        rm(test_file)
    end
end
