import Pkg
Pkg.activate("$(@__DIR__)/..")
Pkg.instantiate()

cd("$(@__DIR__)/..")
include("lines.jl")
lines.main()
@info "Press Enter to quit"
read(stdin, Char)
