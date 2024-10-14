# EasyRAGStore.jl

EasyRAGStore.jl is a Julia package designed for efficient collection, compression, and storage of Retrieval-Augmented Generation (RAG) datasets. It specializes in managing large amounts of textual data with optimized storage utilization, making it ideal for RAG-based applications.

## Key Features

- Efficient collection and storage of RAG datasets, including indices and associated questions
- Advanced compression using RefChunkCompression, which stores repeated chunks as references
- Seamless reading from and writing to JLD2 files for persistent storage

## Core Functionality

EasyRAGStore.jl primarily deals with:

1. **Indices**: Represented as `OrderedDict`s, these are the searchable units in which we store content.
2. **Questions**: Associated with specific indices, these represent queries or tasks performed on the indices.
3. **RefChunks**: A compression mechanism that stores repeated content as references to previous occurrences, significantly reducing storage requirements.

## Installation

EasyRAGStore.jl is currently only available as a development package. To install it, use the following commands in Julia:

```julia
using Pkg
Pkg.develop(url="https://github.com/SixZero/EasyRAGStore.jl.git")
```

## Basic Usage

Here's a simple example demonstrating the core functionality of EasyRAGStore.jl:

```julia
using EasyRAGStore
using OrderedCollections

# Create a new RAGStore
store = RAGStore("my_rag_dataset")

# Create a new index (OrderedDict)
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

In this example, we create a new index and its associated question, append them to the store, and then retrieve them. Behind the scenes, EasyRAGStore.jl uses RefChunkCompression to efficiently store the data, creating references to previously stored chunks when possible.

## Collecting and Storing Datasets

EasyRAGStore.jl can be used to collect and store datasets for RAG applications. Here's an example of how to collect data from various sources and store it in a RAGStore:

```julia
using EasyRAGStore
using OrderedCollections

# Create a new RAGStore for your dataset
store = RAGStore("my_collected_dataset")

# Function to collect data from a source (replace with your actual data collection logic)
function collect_data_from_source(source_id)
    # Simulating data collection
    content = "This is content collected from source $source_id"
    return content
end

# Collect and store data from multiple sources
for i in 1:100
    source_id = "source_$i"
    content = collect_data_from_source(source_id)
    
    # Create an index for this piece of content
    index = OrderedDict(source_id => content)
    
    # Create a sample question (replace with actual question generation logic if available)
    question = (
        question = "What is the content of $source_id?",
        answer = content
    )
    
    # Append to the store
    append!(store, index, question)
end

println("Dataset collection complete. Total indices: ", length(store.dataset_store.indexes))
```

This example demonstrates how to use EasyRAGStore.jl to collect and store a dataset from multiple sources. You can adapt this pattern to your specific data collection needs, whether you're scraping websites, reading from files, or accessing APIs.

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

# Define benchmark configurations
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
