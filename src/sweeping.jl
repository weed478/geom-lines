module Sweeping

export findintersections, hasintersection

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



const ϵ = 1e-4



# Segment

mutable struct Segment{T}
    slope::T
    intercept::T
    line::Line{2, T}
    lineindex::Int
    x1::T
    x2::T
    st::Union{Missing, SMDSemiToken}
end

function Segment(l::Line{2, T}, i::Int) where T
    p1, p2 = l
    x1, y1 = p1
    x2, y2 = p2
    slope = (y2 - y1) / (x2 - x1)
    intercept = y1 - slope * x1
    Segment{T}(slope, intercept, l, i, min(l[1][1], l[2][1]), max(l[1][1], l[2][1]), missing)
end

setsemitoken!(s::Segment, st::SMDSemiToken) = (s.st = st)
getsemitoken(s::Segment) = s.st
clearsemitoken!(s::Segment) = (s.st = missing)



# Intersection

struct Intersection{T}
    i1::Int
    i2::Int
    p::Point{2, T}
end

function Intersection(s1::Segment{T}, s2::Segment{T}, x::T) where T
    Intersection{T}(
        s1.lineindex,
        s2.lineindex,
        Point{2, T}(
            x,
            s1.slope * x + s1.intercept,
        ),
    )
end



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
    abs((a.slope * o.sweepline.x + a.intercept) - (b.slope * o.sweepline.x + b.intercept)) < T(ϵ)
end



# State

struct State{T}
    sc::SortedMultiDict{Segment{T}, Segment{T}, SweepLineOrdering{T}}
end

State(sweepline::SweepLine{T}) where T = State{T}(SortedMultiDict{Segment{T}, Segment{T}}(SweepLineOrdering(sweepline)))

function insert!(state::State{T}, s::Segment{T}) where T
    st = DataStructures.insert!(state.sc, s,  s)
    setsemitoken!(s, st)
end

function delete!(state::State{T}, s::Segment{T}) where T
    DataStructures.delete!((state.sc, getsemitoken(s)))
    clearsemitoken!(s)
end

function pred(state::State{T}, s::Segment{T}) where T
    st = regress((state.sc, getsemitoken(s)))
    if st == beforestartsemitoken(state.sc)
        missing
    else
        deref_value((state.sc, st))
    end
end

function succ(state::State{T}, s::Segment{T}) where T
    st = advance((state.sc, getsemitoken(s)))
    if st == pastendsemitoken(state.sc)
        missing
    else
        deref_value((state.sc, st))
    end
end

function compare(state::State{T}, s1::Segment{T}, s2::Segment{T}) where T
    sc = state.sc
    st1 = getsemitoken(s1)
    st2 = getsemitoken(s2)
    compare(sc, st1, st2)
end

function flip!(state::State{T}, s1::Segment{T}, s2::Segment{T}) where T
    ord = compare(state, s1, s2)
    if ord < 0
        delete!(state, s1)
        delete!(state, s2)
        insert!(state, s2)
        insert!(state, s1)
    elseif ord > 0
        delete!(state, s2)
        delete!(state, s1)
        insert!(state, s1)
        insert!(state, s2)
    else
        throw("flip! arguments were the same segment")
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

function IntersectionEvent(s1::Segment{T}, s2::Segment{T}) where T
    intersectionx = (s2.intercept - s1.intercept) / (s1.slope - s2.slope)
    if s1.slope > s2.slope
        s1, s2 = s2, s1
    end
    IntersectionEvent{T}(s1, s2, intersectionx)
end

getsegments(ev::IntersectionEvent) = (ev.s1, ev.s2)
getpriority(ev::IntersectionEvent) = ev.intersectionx



# Events

struct Events{T}
    q::PriorityQueue{Union{BeginEvent, EndEvent, IntersectionEvent}, T}
end

function Events(lines::Vector{Line{2, T}}) where T
    evq = Events{T}(PriorityQueue{Union{BeginEvent, EndEvent, IntersectionEvent}, T}())
    for (i, line) in enumerate(lines)
        s = Segment(line, i)
        bev = BeginEvent(s)
        eev = EndEvent(s)
        push!(evq, bev)
        push!(evq, eev)
    end
    evq
end

isempty(evq::Events) = isempty(evq.q)
push!(evq::Events, ev::E) where E<:AbstractEvent = enqueue!(evq.q, ev, getpriority(ev))
pop!(evq::Events) = dequeue!(evq.q)

removeintersectionevent!(::Events, ::Missing, ::Segment) = nothing
removeintersectionevent!(::Events, ::Segment, ::Missing) = nothing
removeintersectionevent!(::Events, ::Missing, ::Missing) = nothing

function removeintersectionevent!(evq::Events{T}, s1::Segment{T}, s2::Segment{T}) where T
    if dointersect(s1, s2)
        ev = IntersectionEvent(s1, s2)
        if haskey(evq.q, ev)
            @debug "Removing intersection"
            delete!(evq.q, ev)
        end
    end
end



function orient(a::Point2{T}, b::Point2{T}, c::Point2{T})::Int where T
    M::Matrix{T} = [a[1] a[2] 1
                    b[1] b[2] 1
                    c[1] c[2] 1]

    d::T = det(M)

    if abs(d) < T(ϵ)
        0
    elseif d < 0
        -1
    else
        1
    end
end

function dointersect(s1::Segment{T}, s2::Segment{T}) where T
    a1 = s1.line[1]
    b1 = s1.line[2]
    a2 = s2.line[1]
    b2 = s2.line[2]
    orient(a1, b1, a2) != orient(a1, b1, b2) && orient(a2, b2, a1) != orient(a2, b2, b1)
end

checkintersection!(::Events, ::Segment, ::Missing) = nothing
checkintersection!(::Events, ::Missing, ::Segment) = nothing
checkintersection!(::Events, ::Missing, ::Missing) = nothing

function checkintersection!(evq::Events{T}, s1::Segment{T}, s2::Segment{T}) where T
    if dointersect(s1, s2)
        @debug "New intersection event"
        iev = IntersectionEvent(s1, s2)
        push!(evq, iev)
    end
end



function handleevent!(state::State{T}, evq::Events{T}, ::Vector{Intersection{T}}, ev::BeginEvent{T}) where T
    @debug "Begin event"
    s = getsegment(ev)
    insert!(state, s)
    r = succ(state, s)
    t = pred(state, s)
    removeintersectionevent!(evq, r, t)
    checkintersection!(evq, s, r)
    checkintersection!(evq, s, t)
end

function handleevent!(state::State{T}, evq::Events{T}, ::Vector{Intersection{T}}, ev::EndEvent{T}) where T
    @debug "End event"
    s = getsegment(ev)
    checkintersection!(evq, pred(state, s), succ(state, s))
    delete!(state, s)
end

function handleevent!(state::State{T}, evq::Events{T}, intersections::Vector{Intersection{T}}, ev::IntersectionEvent{T}) where T
    @debug "Intersection event"
    
    s1, s2 = getsegments(ev)
    push!(intersections, Intersection(s1, s2, getpriority(ev)))
    
    flip!(state, s1, s2)

    if compare(state, s1, s2) > 0 
        s1, s2 = s2, s1
    end

    s0 = pred(state, s1)
    s3 = succ(state, s2)

    removeintersectionevent!(evq, s0, s2)
    removeintersectionevent!(evq, s1, s3)

    checkintersection!(evq, s0, s1)
    checkintersection!(evq, s2, s3)
end

function findintersections(lines::Vector{Line{2, T}}) where T
    @debug "Start"
    sweepline = SweepLine(T(-Inf))
    state = State(sweepline)
    evq = Events(lines)

    intersections = Intersection{T}[]

    while !isempty(evq)
        ev = pop!(evq)
        if getpriority(ev) < sweepline.x
            @debug "Got event before sweep line"
            continue
        end
        sweepline.x = getpriority(ev)
        handleevent!(state, evq, intersections, ev)
    end

    intersections
end

function hasintersection(lines::Vector{Line{2, T}})::Bool where T
    length(findintersections(lines)) > 0
end

end