using EasyRAGStore

# Create a temporary directory for the store
store = RAGStore("workspace_context_log_test")

# Start the RAG REPL
println("Starting RAG REPL demo...")
println("Try these commands:")
println("1. Enter a query:")
println("   RAG> What is Julia?")
println()
println("2. Show last query:")
println("   RAG> -q1")
println()
println("3. Add an answer to the last query:")
println("   RAG> -a1 Julia is a high-performance programming language")
println()
println("4. Show last 5 queries:")
println("   RAG> -tail5")
println()
println("Press '}' to enter RAG mode, 'backspace' to exit RAG mode")
println("Press Ctrl+C to exit the demo")

# Start the REPL
start_rag_repl(store)
#%%
using EasyRAGStore: q1, RAGFlow, ensure_loaded!

ensure_loaded!(store)
@show length(store.testcase_store.index_to_cases)
q1(RAGFlow(store))