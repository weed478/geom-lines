module Sweeping

export hasintersection

using GeometryBasics
using DataStructures



# Segment

struct Segment{T}
    slope::T
    intercept::T
    line::Line{2, T}
    x1::T
    x2::T
end

function Segment(l::Line{2, T}) where T
    p1, p2 = line
    x1, y1 = p1
    x2, y2 = p2
    slope = (y2 - y1) / (x2 - x1)
    intercept = y1 - slope * x1
    Segment{T}(slope, intercept, l, min(l[1][1], l[2][1]), max(l[1][1], l[2][1]))
end



# State

struct State{T}

end

Base.delete!(st::State{T}, s::Segment{T}) where T = throw("Not implemented")
pred(st::State{T}, s::Segment{T}) where T = throw("Not implemented")
succ(st::State{T}, s::Segment{T}) where T = throw("Not implemented")
flip!(st::State{T}, s1::Segment{T}, s2::Segment{T}) where T = throw("Not implemented")



# Event types

abstract type AbstractEvent end



# Begin Event

struct BeginEvent{T} <: AbstractEvent
    s::Segment{T}
end

getsegment(ev::BeginEvent) = ev.s
getpriority(ev::BeginEvent) = ev.s.x1



# EndEvent

struct EndEvent <: AbstractEvent

end

getsegment(ev::EndEvent) = ev.s
getpriority(ev::EndEvent) = ev.s.x2



# IntersectionEvent

struct IntersectionEvent{T} <: AbstractEvent
    s1::Segment{T}
    s2::Segment{T}
    intersectionx::T
end

getsegments(ev::IntersectionEvent) = (ev.s1, ev.s2)
getpriority(ev::IntersectionEvent) = ev.intersectionx



# Events

struct Events{T}
    q::PriorityQueue{T, Union{BeginEvent, EndEvent, IntersectionEvent}}
end

function Events(lines::Vector{Line{2, T}}) where T
    Events{T}(PriorityQueue(T, Union{BeginEvent, EndEvent, IntersectionEvent}))
end

Base.isempty(eq::Events) = isempty(eq.q)
Base.push!(eq::Events{T}, ev::E{T}) where T, E<:AbstractEvent = enqueue!(eq.q, ev, getpriority(ev))
Base.pop!(eq::Events) = dequeue!(eq.q)
checkintersection!(eq::Events{T}, s1::Segment{T}, s2::Segment{T}) where T = throw("Not implemented")


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