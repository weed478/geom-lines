module Sweeping

export hasintersection

using GeometryBasics
using DataStructures
using LinearAlgebra: det
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
    evq = Events{T}(PriorityQueue(T, Union{BeginEvent, EndEvent, IntersectionEvent}))
    for line in lines
        bev = BeginEvent(Segment(line))
        eev = EndEvent(Segment(line))
        push!(evq, bev)
        push!(evq, eev)
    end
    evq
end

isempty(evq::Events) = isempty(evq.q)
push!(evq::Events, ev::E) where E<:AbstractEvent = enqueue!(evq.q, ev, getpriority(ev))
pop!(evq::Events) = dequeue!(evq.q)



function orient(a::Point2{T}, b::Point2{T}, c::Point2{T})::Int
    M::Matrix{T} = [a[1] a[2] 1
                    b[1] b[2] 1
                    c[1] c[2] 1]

    d::T = det(M)

    if abs(d) < e
        0
    elseif d < 0
        -1
    else
        1
    end
end

function checkintersection!(evq::Events{T}, s1::Segment{T}, s2::Segment{T}) where T
    a1 = s1.line[1]
    b1 = s1.line[2]
    a2 = s2.line[1]
    b2 = s2.line[2]

    if orient(a1, b1, a2) != orient(a1, b1, b2) && orient(a2, b2, a1) != orient(a2, b2, b1)
        # a1x + b1 = a2x + b2
        # a1x - a2x = b2 - b1
        # x = (b2 - b1) / (a1 - a2)
        intersectionx = (s2.intercept - s1.intercept) / (s1.slope - s2.slope)
        iev = IntersectionEvent(s1, s2, intersectionx)
        push!(evq, iev)
    end
end


function findintersections(lines::Vector{Line{2, T}}) where T
    sweepline = SweepLine(zero(T))
    state = State(sweepline)
    evq = Events(lines)

    intersections = []

    while !isempty(evq)
        ev = pop!(evq)
        sweepline.x = getpriority(ev)

        if ev isa BeginEvent
            s = getsegment(ev)
            insert!(state, s)
            checkintersection!(evq, s, succ(state, s))
            checkintersection!(evq, s, pred(state, s))
        elseif E isa EndEvent
            s = getsegment(ev)
            checkintersection!(evq, pred(state, s), succ(state, s))
            delete!(state, s)
        else # IntersectionEvent
            s1, s2 = getsegments(ev)
            push!(intersections, (s1, s2))
            flip!(state, s1, s2)
            if compare(state, s1, s2) > 0
                checkintersection!(evq, s1, pred(state, s1))
                checkintersection!(evq, s2, succ(state, s2))
            else
                checkintersection!(evq, s1, succ(state, s1))
                checkintersection!(evq, s2, pred(state, s2))
            end
        end
    end

    intersections
end

function hasintersection(lines::Vector{Line{2, T}})::Bool where T
    length(findintersections(lines)) > 0
end

end