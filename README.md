# EasyRAGStore.jl

EasyRAGStore.jl is a Julia package designed to efficiently manage and store Retrieval-Augmented Generation (RAG) datasets and associated test cases. It provides a robust framework for compressing, storing, and retrieving large amounts of textual data, making it ideal for RAG-based applications.

## Features

- Efficient storage of multiple indices in a single file
- Advanced compression techniques using RefChunkCompression
- Separate storage for dataset indices and test cases
- Easy-to-use API for appending, retrieving, and managing data
- Integration with EasyRAGBench.jl for benchmarking and evaluation

## Installation

EasyRAGStore.jl is currently only available as a development package. To install it, use the following commands in Julia:

using Pkg
Pkg.develop(url="https://github.com/your-username/EasyRAGStore.jl.git")


Replace `your-username` with the actual GitHub username or organization where the package is hosted.

## Usage

Here's a basic example of how to use EasyRAGStore.jl:

```Processing diff with AI for higher quality...
julia
using EasyRAGStore
using OrderedCollections

# Create a new RAGStore
store = RAGStore("my_rag_dataset")

# Create a new index
new_index = OrderedDict(
    "source1" => "This is the content of source 1.",
    "source2" => "This is the content of source 2."
)

# Create a question associated with this index
question = (
    question = "What is the content of source 1?",
    answer = "This is the content of source 1."
)

# Append the index and question to the store
index_id = append!(store, new_index, question)

# Retrieve the index
retrieved_index = get_index(store, index_id)
println("Retrieved index: ", retrieved_index)

# Get questions for the index
questions = get_questions(store, index_id)
println("Questions for index: ", questions)

# Save the store (this is done automatically after appending, but can be called manually)
save_store(store)
```

## Compression

EasyRAGStore.jl uses a sophisticated compression strategy called RefChunkCompression. This strategy identifies repeated chunks across different indices and stores them as references, significantly reducing the overall storage size.

## Integration with EasyRAGBench.jl

EasyRAGStore.jl is designed to work seamlessly with EasyRAGBench.jl for benchmarking and evaluating RAG systems. Here's an example of how to use them together:

```julia
using EasyRAGStore
using EasyRAGBench

# Load an existing RAGStore
store = RAGStore("my_rag_dataset")

# Generate solutions for all indices in the store
generate_all_solutions(store, "all_solutions.jld2")

# Define benchmark configurations[ Info: Tokens: 821 @ Cost: $0.0002 in 7.6 seconds

configs = [
    BenchmarkConfig(embedding_model="voyage-code-2", top_k=120, batch_size=50, reranker_model="gpt4om", top_n=10),
    BenchmarkConfig(embedding_model="voyage-code-2", top_k=40, batch_size=50, reranker_model="gpt4om", top_n=10),
]

# Run benchmarks
results = run_example_evaluation(configs)
```

## Contributing

Contributions to EasyRAGStore.jl are welcome! Please feel free to submit issues, feature requests, or pull requests on our GitHub repository.

## License

EasyRAGStore.jl is released under the MIT License. See the LICENSE file for more details.