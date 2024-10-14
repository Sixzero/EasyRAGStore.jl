# EasyRAGStore.jl

EasyRAGStore.jl is a Julia package designed to efficiently manage and store Retrieval-Augmented Generation (RAG) datasets and associated test cases. It provides a robust framework for compressing, storing, and retrieving large amounts of textual data, making it ideal for RAG-based applications.

## Features

- Efficient storage of multiple indices in a single file
- Advanced compression techniques using RefChunkCompression
- Separate storage for dataset indices and test cases
- Easy-to-use API for appending, retrieving, and managing data
- Integration with EasyRAGBench.jl for benchmarking and evaluation

## Installation

To install EasyRAGStore.jl, use the Julia package manager:

using Pkg
Pkg.add("EasyRAGStore")

## Usage

Here's a basic example of how to use EasyRAGStore.jl:

