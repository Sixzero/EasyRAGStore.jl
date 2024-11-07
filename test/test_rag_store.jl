using Test
using EasyRAGStore: RAGStore, get_index, get_questions, append!, save_store
using EasyRAGStore
using OrderedCollections
using Dates

@testset "RAGStore Tests" begin
    function create_test_dir()
        joinpath(tempdir(), "easyragbench_test_$(Dates.format(now(), "yyyymmdd_HHMMSS_$(rand(1000:9999))"))")
    end

    @testset "Basic RAGStore operations" begin
        test_cache_dir = create_test_dir()
        mkdir(test_cache_dir)
        store = RAGStore(test_cache_dir)
        
        # Test appending an index and question
        index1 = OrderedDict("source1" => "content1", "source2" => "content2")
        question1 = (question="What is the content?", answer="content1 and content2")
        index_id1 = append!(store, index1, question1)
        
        # Test retrieving the index and question
        retrieved_index = get_index(store, index_id1)
        @test retrieved_index == index1
        
        retrieved_questions = get_questions(store, index_id1)
        @test length(retrieved_questions) == 1
        @test retrieved_questions[1] == question1
        
        # Test appending another index and question
        index2 = OrderedDict("source3" => "content3", "source4" => "content4")
        question2 = (question="What is the new content?", answer="content3 and content4")
        index_id2 = append!(store, index2, question2)
        
        # Test retrieving all questions
        all_questions = get_questions(store, index_id2)
        @test length(all_questions) == 1
        @test all_questions[1] == question2
        
        # Test appending the same index with a different question
        question3 = (question="What is the first content again?", answer="content1 and content2")
        index_id3 = append!(store, index1, question3)
        
        # Verify that the new question is added to the existing index
        updated_questions = get_questions(store, index_id3)
        @test length(updated_questions) == 2
        @test updated_questions[1] == question1
        @test updated_questions[2] == question3
        
        # Verify that the index content remains the same
        @test get_index(store, index_id3) == index1
        
        # Test saving and loading the store
        save_store(joinpath(test_cache_dir, "rag_store"), store)
        loaded_store = RAGStore(joinpath(test_cache_dir, "rag_store"))
        
        # Verify loaded store
        @test get_index(loaded_store, index_id1) == index1
        @test get_index(loaded_store, index_id2) == index2
        @test get_index(loaded_store, index_id3) == index1
        @test get_questions(loaded_store, index_id1) == [question1, question3]
        @test get_questions(loaded_store, index_id2) == [question2]
        @test get_questions(loaded_store, index_id3) == [question1, question3]
        
        # Clean up
        rm(test_cache_dir, recursive=true)
    end

    @testset "Multiple appends of the same index" begin
        test_cache_dir = create_test_dir()
        mkdir(test_cache_dir)
        store = RAGStore(test_cache_dir)
        
        # Create a test index
        index = OrderedDict("source1" => "content1", "source2" => "content2")
        
        # Append the same index multiple times with different questions
        question1 = (question="First question?", answer="Answer 1")
        question2 = (question="Second question?", answer="Answer 2")
        question3 = (question="Third question?", answer="Answer 3")
        
        index_id1 = append!(store, index, question1)
        index_id2 = append!(store, index, question2)
        index_id3 = append!(store, index, question3)
        
        # Test that all index IDs are the same
        @test index_id1 == index_id2 == index_id3
        
        # Verify that the index content remains the same
        @test get_index(store, index_id1) == index
        
        # Verify that all questions are associated with the same index
        all_questions = get_questions(store, index_id1)
        @test length(all_questions) == 3
        @test all_questions[1] == question1
        @test all_questions[2] == question2
        @test all_questions[3] == question3
        
        # Test saving and loading the store
        save_store(joinpath(test_cache_dir, "rag_store"), store)
        loaded_store = RAGStore(joinpath(test_cache_dir, "rag_store"))
        
        # Verify loaded store
        @test get_index(loaded_store, index_id1) == index
        loaded_questions = get_questions(loaded_store, index_id1)
        @test length(loaded_questions) == 3
        @test loaded_questions[1] == question1
        @test loaded_questions[2] == question2
        @test loaded_questions[3] == question3
        
        # Clean up
        rm(test_cache_dir, recursive=true)
    end

    @testset "Automatic saving and loading" begin
        test_cache_dir = create_test_dir()
        mkdir(test_cache_dir)
        store = RAGStore(test_cache_dir)
        
        index = OrderedDict("source1" => "content1", "source2" => "content2")
        question = (question="Test question?", answer="Test answer")
        
        index_id = append!(store, index, question)
        
        # Create a new store instance, which should load the saved data
        new_store = RAGStore(test_cache_dir)
        
        @test get_index(new_store, index_id) == index
        @test get_questions(new_store, index_id) == [question]

        # Clean up
        rm(test_cache_dir, recursive=true)
    end
    
    @testset "Concurrent operations" begin
        test_cache_dir = create_test_dir()
        mkdir(test_cache_dir)
        store = RAGStore("test", test_cache_dir)
        
        # Test concurrent appends
        n_tasks = 10
        tasks = map(1:n_tasks) do i
            @async begin
                index = OrderedDict("source$i" => "content$i")
                question = (question="Question $i", answer="Answer $i")
                append!(store, index, question)
            end
        end
        
        # Wait for all tasks
        index_ids = fetch.(tasks)
        
        # Verify all entries were saved
        @test length(unique(index_ids)) == n_tasks
        for i in 1:n_tasks
            questions = get_questions(store, index_ids[i])
            @test length(questions) == 1
            @test questions[1].question == "Question $i"
        end
        
        # Clean up
        rm(test_cache_dir, recursive=true)
    end
end
;
