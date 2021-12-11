module Sweeping

export hasintersection

using GeometryBasics
using DataStructures



# State

struct State

end

Base.delete!(st::State, s) = throw("Not implemented")
pred(st::State, s) = throw("Not implemented")
succ(st::State, s) = throw("Not implemented")
flip!(st::State, s1, s2) = throw("Not implemented")



# Event types

abstract type AbstractEvent end



# Begin Event

struct BeginEvent <: AbstractEvent

end

getsegment(ev::BeginEvent) = throw("Not implemented")
getpriority(ev::BeginEvent) = throw("Not implemented")



# EndEvent

struct EndEvent <: AbstractEvent

end

getsegment(ev::EndEvent) = throw("Not implemented")
getpriority(ev::EndEvent) = throw("Not implemented")



# IntersectionEvent

struct IntersectionEvent <: AbstractEvent

end

getsegments(ev::IntersectionEvent) = throw("Not implemented")
getpriority(ev::IntersectionEvent) = throw("Not implemented")



# Events

struct Events{T}
    q::PriorityQueue{T, Union{BeginEvent, EndEvent, IntersectionEvent}}
end

function Events(lines::Vector{Line{2, T}}) where T
    Events{T}(PriorityQueue(T, Union{BeginEvent, EndEvent, IntersectionEvent}))
end

Base.isempty(eq::Events) = isempty(eq.q)
Base.push!(eq::Events, ev::E) where E<:AbstractEvent = enqueue!(eq.q, ev, getpriority(ev))
Base.pop!(eq::Events) = dequeue!(eq.q)
checkintersection!(eq::Events, s1, s2) = throw("Not implemented")


function findintersections(lines::Vector{Line{2, T}}) where T
    st = State()
    eq = Events(lines)

    intersections = []

    while !isempty(eq)
        ev = pop!(eq)

        if ev isa BeginEvent
            s = getsegment(ev)
            push!(st, s)
            checkintersection(eq, s, succ(st, s))
            checkintersection(eq, s, pred(st, s))
        elseif E isa EndEvent
            s = getsegment(ev)
            checkintersection(pred(st, s), succ(st, s))
            delete!(st, s)
        else # IntersectionEvent
            s1, s2 = getsegments(ev)
            push!(intersections, (s1, s2))
            flip!(st, s1, s2)
            if succ(st, s1) === s2
                checkintersection(eq, s1, pred(st, s1))
                checkintersection(eq, s2, succ(st, s2))
            else
                checkintersection(eq, s1, succ(st, s1))
                checkintersection(eq, s2, pred(st, s2))
            end
        end
    end

    intersections
end

function hasintersection(lines::Vector{Line{2, T}})::Bool where T
    length(findintersections(lines)) > 0
end

end