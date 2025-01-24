using ReplMaker
using REPL.LineEdit: MIState, PromptState, default_keymap, escape_defaults
using Base.Filesystem
using Base: AnyDict, basename, rstrip
using OrderedCollections
using Markdown

mutable struct RAGFlow
    store::RAGStore
    last_queries::Vector{NamedTuple}
    last_index_id::Union{String, Nothing}
end

RAGFlow(store::RAGStore) = RAGFlow(store, NamedTuple[], nothing)

# Helper function to show first N and last M lines of text
function truncate_head_tail(text::AbstractString, head::Int=3, tail::Int=5)
    lines = split(text, '\n')
    if length(lines) <= head + tail
        return text
    end
    head_part = join(lines[1:head], "\n")
    tail_part = join(lines[end-tail+1:end], "\n")
    return head_part * "\n...\n" * tail_part
end

# Helper function to print Q&A
function print_qa(q::NamedTuple, prefix::String="")
    md = """
    $prefix**Q:** 
    ```
    $(truncate_head_tail(q.question))
    ```
    """
    if hasfield(typeof(q), :answer)
        md *= """
        **A:** 
        ```
        $(q.answer)
        ```
        """
    end
    println(Markdown.parse(md))
end

# Helper function to print sources
function print_sources(sources::Vector{String}, max_sources::Int=5)
    !isempty(sources) || return
    shown_sources = sources[1:min(length(sources), max_sources)]
    md = """
    **Sources:**
    $(join(["* $src" for src in shown_sources], "\n"))
    """
    if length(sources) > max_sources
        md *= "\n* ... and $(length(sources) - max_sources) more"
    end
    println(Markdown.parse(md))
end

function tail5(flow::RAGFlow)
    isnothing(flow.last_index_id) && return println("\nNo queries yet.")
    questions = get_questions(flow.store, flow.last_index_id)
    n = min(5, length(questions))
    println("\nLast $n queries:")
    for (i, q) in enumerate(questions[end-n+1:end])
        print("$i. ")
        print_qa(q)
    end
end

function q1(flow::RAGFlow)
    ensure_loaded!(flow.store)
    latest = reduce(flow.store.testcase_store.index_to_cases; init=nothing) do acc, (idx, cases)
        case = isempty(cases) ? nothing : cases[end]
        isnothing(case) ? acc : isnothing(acc) || get(case, :timestamp, DateTime(0)) > get(acc[2], :timestamp, DateTime(0)) ? (idx, case) : acc
    end
    isnothing(latest) && return println("\nNo cases yet.")
    
    (index_id, last_case) = latest
    flow.last_index_id = index_id
    println("**Last case:**")
    print_qa(last_case)
    print_sources(collect(keys(get_index(flow.store, index_id))))
end

function a1!(flow::RAGFlow, args::String)
    isnothing(flow.last_index_id) && return println("\nNo queries yet.")
    questions = get_questions(flow.store, flow.last_index_id)
    isempty(questions) && return println("\nNo queries yet.")
    
    last_q = questions[end]
    # Add true_answers as array of strings
    true_answers = split(strip(args), ' ')
    # Create updated question with new true_answers but keep other fields
    updated_q = if haskey(last_q, :true_answers)
        # Append to existing true_answers
        merge(last_q, (true_answers=vcat(last_q.true_answers, true_answers),))
    else
        merge(last_q, (true_answers=true_answers,))
    end
    
    update_last_question!(flow.store.testcase_store, flow.last_index_id, updated_q)
    println("\nTrue answers added for last query.")
end

function w1!(flow::RAGFlow, args::String)
    isnothing(flow.last_index_id) && return println("\nNo queries yet.")
    questions = get_questions(flow.store, flow.last_index_id)
    isempty(questions) && return println("\nNo queries yet.")
    
    last_q = questions[end]
    # Add wrong_answers as array of strings
    wrong_answers = split(strip(args), ' ')
    # Create updated question with new wrong_answers but keep other fields
    updated_q = if haskey(last_q, :wrong_answers)
        # Append to existing wrong_answers
        merge(last_q, (wrong_answers=vcat(last_q.wrong_answers, wrong_answers),))
    else
        merge(last_q, (wrong_answers=wrong_answers,))
    end
    
    update_last_question!(flow.store.testcase_store, flow.last_index_id, updated_q)
    println("\nWrong answers added for last query.")
end

const COMMANDS = Dict{String, Tuple{String, Function}}(
    "-tail5" => ("Show last 5 queries", (flow, _) -> tail5(flow)),
    "-q1"    => ("Show last query", (flow, _) -> q1(flow)),
    "-a1"    => ("Add true answers to last query", (flow, args) -> a1!(flow, args)),
    "-w1"    => ("Add wrong answers to last query", (flow, args) -> w1!(flow, args)),
    "--revise" => ("Run Revise.revise()", (flow, args) -> begin
        try
            @eval Main using Revise
            @eval Main Revise.revise()
            println("\nRevise: Code changes have been applied!")
        catch e
            println("\nError running Revise: ", e)
        end
    end),
)
COMMANDS["-r"] = (COMMANDS["--revise"][1], COMMANDS["--revise"][2])  # Add revise alias

function rag_parser(input::AbstractString, flow::RAGFlow)
    cmd = strip(input)
    isempty(cmd) && return

    for (prefix, (_, handler)) in COMMANDS
        if startswith(cmd, prefix * " ") || cmd == prefix
            handler(flow, strip(cmd[length(prefix)+1:end]))
            return
        end
    end

    # Handle as new query
    index = OrderedDict("query" => cmd)
    question = (question=cmd, answer="")
    flow.last_index_id = append!(flow.store, index, question)
    push!(flow.last_queries, question)
    println("\nQuery added.")
end

function create_rag_repl(store::RAGStore)
    flow = RAGFlow(store)
    parser(input) = rag_parser(input, flow)
    
    repl = Base.active_repl
    initrepl(
        parser;
        prompt_text="RAG> ",
        prompt_color=:cyan,
        start_key='}',
        mode_name=:rag,
        repl=repl,
        valid_input_checker=Returns(true),
        sticky_mode=false
    )
end

function start_rag_repl(store::RAGStore)
    if isdefined(Base, :active_repl)
        rag_mode = create_rag_repl(store)
        println("RAG REPL initialized. Press '}' to enter and backspace to exit.")
        println("\nAvailable commands:")
        for (cmd, (desc, _)) in sort(collect(COMMANDS))
            println("  $cmd : $desc")
        end
    else
        atreplinit() do repl
            rag_mode = create_rag_repl(store)
            println("RAG REPL initialized. Press '}' to enter and backspace to exit.")
            println("\nAvailable commands:")
            for (cmd, (desc, _)) in sort(collect(COMMANDS))
                println("  $cmd : $desc")
            end
        end
    end
end

export start_rag_repl
