struct AnimationFrame{T}
    state::Vector{Point{2, T}}
    begins::Vector{Point{2, T}}
    ends::Vector{Point{2, T}}
    intersections::Vector{Point{2, T}}
    allintersects::Vector{Point{2, T}}
    sweepline::T
end

pushframe!(::Missing, args...) = missing

function pushframe!(frames::Vector{AnimationFrame{T}}, st::State{T}, evq::Events{T}, sweepline::SweepLine{T}, intersects::Vector{Intersection{T}}) where T
    state = Point{2, T}[]
    begins = Point{2, T}[]
    ends = Point{2, T}[]
    intersections = Point{2, T}[]
    allintersects = Point{2, T}[]

    for (ev, x) in evq.q
        if ev isa BeginEvent
            push!(begins, Point{2, T}(x, ev.s.slope * x + ev.s.intercept))
        elseif ev isa EndEvent
            push!(ends, Point{2, T}(x, ev.s.slope * x + ev.s.intercept))
        else
            push!(intersections, Point{2, T}(x, ev.s1.slope * x + ev.s1.intercept))
        end
    end

    for (s, n) in st.sc
        push!(state, s.line[1])
        push!(state, s.line[2])
    end

    for i in intersects
        push!(allintersects, i.p)
    end

    frame = AnimationFrame(
        state,
        begins,
        ends,
        intersections,
        allintersects,
        sweepline.x,
    )
    push!(frames, frame)
end
