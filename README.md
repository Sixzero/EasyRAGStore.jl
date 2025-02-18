# EasyRAGStore.jl

EasyRAGStore.jl is a lightweight Julia package for efficient storage and retrieval of RAG (Retrieval-Augmented Generation) datasets. It specializes in managing large amounts of textual data with optimized storage utilization, making it ideal for RAG-based applications.

## Key Features

- Efficient storage of text chunks with optimized storage utilization
- `RefChunkCompression` for optimized storage, which stores repeated chunks as `Ref`s
- Simple and efficient search interface with embedding and reranking capabilities
- Reading/writing with JLD2 for persistent storage

## Installation

```julia
using Pkg
Pkg.develop(url="https://github.com/SixZero/EasyRAGStore.jl.git")
```

## Basic Usage

Here's a simple example demonstrating the core functionality:

```julia
using EasyRAGStore

# Create a RAG pipeline with embedding and reranking
rag_pipeline = TwoLayerRAG(
    topK=TopK([create_voyage_embedder(), bm25()], top_k=50), # Combines embedding and BM25 scores
    reranker=ReduceGPTReranker(batch_size=30, top_n=10, model="gem20f")
)

# Your text chunks
vec_of_strings = [
    "This is the first document.",
    "Here is another document.",
    "And a third one with different content."
]

# Search in the chunks
query = "Which document talks about different content?"
search_results = search(rag_pipeline, vec_of_strings, query)

# The same pipeline can be used with different text collections
vec_of_strings2 = ["Another set of documents", "With different content"]
search_results2 = search(rag_pipeline, vec_of_strings2, query)
```

## Advanced Pipeline Configuration

You can customize the RAG pipeline based on your needs:

```julia
# Example of a more detailed pipeline setup
rag_pipeline = TwoLayerRAG(
    topK=TopK(
        [
            create_voyage_embedder(),  # Embedding-based search
            bm25()                     # BM25 text search
        ],
        top_k=50                      # Number of initial candidates
    ),
    reranker=ReduceGPTReranker(
        batch_size=30,                # Batch size for reranking
        top_n=10,                     # Number of results after reranking
        model="gem20f"                # Model used for reranking
    )
)
```

This configuration:
1. Combines embedding-based and BM25 search scores
2. Selects top 50 candidates
3. Reranks them using a GPT model
4. Returns the top 10 most relevant results

## Contributing

Contributions to EasyRAGStore.jl are welcome! Please feel free to submit issues, feature requests, or pull requests on our GitHub repository.

## License

EasyRAGStore.jl is released under the MIT License. See the LICENSE file for more details.
