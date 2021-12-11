module Sweeping

export hasintersection

using GeometryBasics

function findintersections(lines::Vector{Line{2, T}}) where T
    []
end

function hasintersection(lines::Vector{Line{2, T}})::Bool where T
    length(findintersections(lines)) > 0
end

end