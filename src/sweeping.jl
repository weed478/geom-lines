module Sweeping

export hasintersection

using GeometryBasics
using DataStructures
import Base.push!
import Base.pop!
import Base.insert!
import Base.delete!
import Base.isempty
import Base.Ordering
import Base.lt
import DataStructures.eq
import DataStructures.compare



# Segment

mutable struct Segment{T}
    slope::T
    intercept::T
    line::Line{2, T}
    x1::T
    x2::T
    st::Union{Missing, SMDSemiToken}
end

function Segment(l::Line{2, T}) where T
    p1, p2 = line
    x1, y1 = p1
    x2, y2 = p2
    slope = (y2 - y1) / (x2 - x1)
    intercept = y1 - slope * x1
    Segment{T}(slope, intercept, l, min(l[1][1], l[2][1]), max(l[1][1], l[2][1]), missing)
end

setsemitoken!(s::Segment, st::SMDSemiToken) = (s.st = st)
getsemitoken(s::Segment) = s.st
clearsemitoken!(s::Segment) = setsemitoken!(s, missing)



# SweepLine

mutable struct SweepLine{T}
    x::T
end



# SweepLineOrdering

struct SweepLineOrdering{T} <: Ordering
    sweepline::SweepLine{T}
end

function lt(o::SweepLineOrdering{T}, a::Segment{T}, b::Segment{T}) where T
    !eq(o, a, b) && isless(a.slope * o.sweepline.x + a.intercept, b.slope * o.sweepline.x + b.intercept)
end

function eq(o::SweepLineOrdering{T}, a::Segment{T}, b::Segment{T}) where T
    abs((a.slope * o.sweepline.x + a.intercept) - (b.slope * o.sweepline.x + b.intercept)) < T(1e-10)
end



# State

struct State{T}
    sc::SortedMultiDict{Segment{T}, Segment{T}, SweepLineOrdering{T}}
end

State(sweepline::SweepLine{T}) where T = State{T}(SortedMultiDict{Segment{T}, Segment{T}}(SweepLineOrdering(sweepline)))

function insert!(state::State{T}, s::Segment{T}) where T
    st = insert!(state.sc, s, s)
    setsemitoken!(s, st)
end

function delete!(state::State{T}, s::Segment{T}) where T
    DataStructures.delete!((state.sc, getsemitoken(s)))
    clearsemitoken!(s)
end

pred(state::State{T}, s::Segment{T}) where T = deref((state.sc, regress((state.sc, getsemitoken(s)))))
succ(state::State{T}, s::Segment{T}) where T = deref((state.sc, advance((state.sc, getsemitoken(s)))))

function compare(state::State{T}, s1::Segment{T}, s2::Segment{T}) where T
    sc = state.sc
    st1 = getsemitoken(s1)
    st2 = getsemitoken(s2)
    compare(sc, st1, st2)
end

function flip!(state::State{T}, s1::Segment{T}, s2::Segment{T}) where T
    if compare(state, s1, s2) < 0
        pop!(state, s1)
        push!(state, s1)
    else
        pop!(state, s2)
        push!(state, s2)
    end
end



# Event types

abstract type AbstractEvent end



# Begin Event

struct BeginEvent{T} <: AbstractEvent
    s::Segment{T}
end

getsegment(ev::BeginEvent) = ev.s
getpriority(ev::BeginEvent) = ev.s.x1



# EndEvent

struct EndEvent{T} <: AbstractEvent
    s::Segment{T}
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

isempty(eq::Events) = isempty(eq.q)
push!(eq::Events, ev::E) where E<:AbstractEvent = enqueue!(eq.q, ev, getpriority(ev))
pop!(eq::Events) = dequeue!(eq.q)
checkintersection!(eq::Events{T}, s1::Segment{T}, s2::Segment{T}) where T = throw("Not implemented")


function findintersections(lines::Vector{Line{2, T}}) where T
    sweepline = SweepLine(zero(T))
    st = State(sweepline)
    eq = Events(lines)

    intersections = []

    while !isempty(eq)
        ev = pop!(eq)
        sweepline.x = getpriority(ev)

        if ev isa BeginEvent
            s = getsegment(ev)
            push!(st, s)
            checkintersection!(eq, s, succ(st, s))
            checkintersection!(eq, s, pred(st, s))
        elseif E isa EndEvent
            s = getsegment(ev)
            checkintersection!(eq, pred(st, s), succ(st, s))
            pop!(st, s)
        else # IntersectionEvent
            s1, s2 = getsegments(ev)
            push!(intersections, (s1, s2))
            flip!(st, s1, s2)
            if succ(st, s1) === s2
                checkintersection!(eq, s1, pred(st, s1))
                checkintersection!(eq, s2, succ(st, s2))
            else
                checkintersection!(eq, s1, succ(st, s1))
                checkintersection!(eq, s2, pred(st, s2))
            end
        end
    end

    intersections
end

function hasintersection(lines::Vector{Line{2, T}})::Bool where T
    length(findintersections(lines)) > 0
end

end