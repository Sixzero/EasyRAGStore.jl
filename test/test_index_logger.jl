using Test
using EasyRAGStore: IndexLogger, log_index, get_logged_indices
using Dates

@testset "IndexLogger with Vector{String} Tests" begin
    @testset "Basic logging operations" begin
        # Create a temporary directory for testing
        test_dir = joinpath(tempdir(), "index_logger_test_$(rand(1000:9999))")
        mkpath(test_dir)
        
        try
            # Create logger
            logger = IndexLogger(joinpath(test_dir, "test_log"))
            
            # Test simple chunks
            chunks1 = ["This is chunk 1", "This is chunk 2"]
            log_index(logger, chunks1, "What are these chunks?")
            
            # Test another set of chunks
            chunks2 = ["Another chunk", "Yet another chunk", "Third chunk"]
            log_index(logger, chunks2, "Tell me about these chunks")
            
            # Get logged indices
            logs = get_logged_indices(logger)
            
            @test length(logs) == 2
            @test any(log -> log.question == "What are these chunks?", logs)
            @test any(log -> log.question == "Tell me about these chunks", logs)
            
            # Test date filtering
            yesterday = Dates.now() - Dates.Day(1)
            today_logs = get_logged_indices(logger, start_date=yesterday)
            @test length(today_logs) == 2
            
            # Test question filtering
            chunk_logs = get_logged_indices(logger, question_filter="these chunks")
            @test length(chunk_logs) == 2
            
            what_logs = get_logged_indices(logger, question_filter="What")
            @test length(what_logs) == 1
            
            # Test with answer
            chunks3 = ["Chunk with answer"]
            log_index(logger, chunks3, "Question with answer?", answer="This is the answer")
            
            answer_logs = get_logged_indices(logger, question_filter="answer")
            @test length(answer_logs) == 1
            @test haskey(first(answer_logs), :returned_answer)
            @test first(answer_logs).returned_answer == "This is the answer"
            
        finally
            # Cleanup
            rm(test_dir, recursive=true)
        end
    end
    
    @testset "Concurrent logging" begin
        test_dir = joinpath(tempdir(), "index_logger_concurrent_test_$(rand(1000:9999))")
        mkpath(test_dir)
        
        try
            logger = IndexLogger(joinpath(test_dir, "concurrent_log"))
            
            # Create multiple tasks to log concurrently
            tasks = [@async begin
                chunks = ["Concurrent chunk $i-1", "Concurrent chunk $i-2"]
                log_index(logger, chunks, "Concurrent question $i")
            end for i in 1:5]
            
            # Wait for all tasks
            foreach(wait, tasks)
            
            # Verify logs
            logs = get_logged_indices(logger)
            @test length(logs) == 5
            @test all(log -> startswith(log.question, "Concurrent question"), logs)
            
        finally
            rm(test_dir, recursive=true)
        end
    end
end
