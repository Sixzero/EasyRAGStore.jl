using Test
using EasyRAGStore: IndexLogger, log_index, get_logged_indices, ensure_saved
using Dates
using EasyContext: FileChunk, SourceChunk, SourcePath  # Add SourceChunk to imports

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
    @testset "IndexLogger Storage Tests" begin
        test_dir = joinpath(tempdir(), "index_logger_storage_test_$(rand(1000:9999))")
        mkpath(test_dir)
        
        try
            # Create logger and log some data
            logger = IndexLogger(joinpath(test_dir, "storage_test"))
            
            # Test data
            chunks = ["Test chunk 1", "Test chunk 2"]
            question = "What are these chunks about?"
            answer = "These are test chunks"
            
            # Log with answer
            log_index(logger, chunks, question, answer=answer)
            
            # Force save by creating new logger instance
            logger = nothing
            GC.gc()
            
            # Try to load the data directly using JLD2
            store_path = joinpath(test_dir, "storage_test_testcase.jld2")
            @show store_path
            @test isfile(store_path)
            
            # Load and verify data
            data = JLD2.load(store_path)  # Simplified loading
            
            @test haskey(data, "index_to_cases")
            cases = data["index_to_cases"]
            @test !isempty(cases)
            
            # Create new logger and verify retrieval
            new_logger = IndexLogger(joinpath(test_dir, "storage_test"))
            logs = get_logged_indices(new_logger)
            
            @test length(logs) == 1
            log_entry = first(logs)
            @test log_entry.question == question
            @test log_entry.returned_answer == answer
            
        finally
            rm(test_dir, recursive=true)
        end
    end

    @testset "IndexLogger with FileChunk Tests" begin
        test_dir = joinpath(tempdir(), "index_logger_filechunk_test_$(rand(1000:9999))")
        mkpath(test_dir)
        
        try
            # Create logger
            logger = IndexLogger(joinpath(test_dir, "test_log"))
            
            # Test FileChunk data
            chunks = [
                FileChunk(source=SourcePath(path="file1.txt"), content="Test content 1"),
                FileChunk(source=SourcePath(path="file2.txt"), content="Test content 2")
            ]
            question = "What are these chunks about?"
            answer = "These are test chunks"
            
            # Log with answer
            log_index(logger, chunks, question, answer=answer)
            
            # Force save by creating new logger instance
            logger = nothing
            GC.gc()
            
            # Try to load the data directly using JLD2
            store_path = joinpath(test_dir, "test_log_testcase.jld2")
            @test isfile(store_path)
            
            # Create new logger and verify retrieval
            new_logger = IndexLogger(joinpath(test_dir, "test_log"))
            logs = get_logged_indices(new_logger)
            
            @test length(logs) == 1
            log_entry = first(logs)
            @test log_entry.question == question
            @test log_entry.returned_answer == answer
            
        finally
            rm(test_dir, recursive=true)
        end
    end

    @testset "IndexLogger with Mixed Chunk Types Tests" begin
        test_dir = joinpath(tempdir(), "index_logger_mixed_test_$(rand(1000:9999))")
        mkpath(test_dir)
        
        try
            # Create logger
            logger = IndexLogger(joinpath(test_dir, "test_log"))
            
            # Test mixed chunk types
            chunks = [
                FileChunk(source=SourcePath(path="file1.txt"), content="File content 1"),
                FileChunk(source=SourcePath(path="file3.txt", from_line=1, to_line=10), content="File content with lines")
            ]
            chunks2 = [
                SourceChunk(source=SourcePath(path="file2.txt"), content="Source content 2", containing_module="TestModule"),
            ]
            chunks3 = [
                "Just some string chunks", "And some more string chunks"
            ]
            question = "What are these mixed chunks about?"
            answer = "These are mixed type chunks"
            
            # Log with answer
            log_index(logger, chunks, question, answer=answer)
            log_index(logger, chunks2, question *"2", answer=answer)
            log_index(logger, chunks3, question *"3", answer=answer)
            
            # Ensure all writes are completed
            ensure_saved(logger)
            
            # Try to load the data directly using JLD2
            store_path = joinpath(test_dir, "test_log_testcase.jld2")
            @test isfile(store_path)
            
            # Create new logger and verify retrieval
            new_logger = IndexLogger(joinpath(test_dir, "test_log"))
            logs = get_logged_indices(new_logger)
            
            @test length(logs) == 3
            log_entry = first(logs)
            @test log_entry.question == question
            @test log_entry.returned_answer == answer

            logger2 = IndexLogger(joinpath(test_dir, "test_log"))
            logs2 = get_logged_indices(logger2)
            @test length(logs2) == 3
            log_entry2 = first(logs2)
            @test log_entry2.question == question
            @test log_entry2.returned_answer == answer
        finally
            rm(test_dir, recursive=true)
        end
    end

end
