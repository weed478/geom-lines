module gui

using GLMakie
using GeometryBasics
using Distributions: Uniform

import ..Sweeping

function savesegments(points, filename)
    open(filename, "w") do f
        for (x, y) in points
            println(f, "$x $y")
        end
    end
end

function loadsegments(filename)::Union{Vector{Point2f}, Nothing}
    points = Point2f[]
    for line in readlines(filename)
        x, y = parse.(Float32, split(line))
        push!(points, Point2f(x, y))
    end
    points
end

function run()
    fig = Figure()
    fig[1, 2] = infogrid = GridLayout(tellwidth=false, tellheight=true)
    fig[2, 2] = controlsgrid = GridLayout(tellwidth=false, tellheight=false)
    ax = Axis(fig[1:2, 1])
    deregister_interaction!(ax, :rectanglezoom)

    points = Node(Point2f[])

    scatter!(
        ax,
        points,
    )

    linesegments!(
        ax,
        points,
    )

    # intersections

    hasintersection = Node(false)
    intersectionpoints = Node(Point2f[])

    on(points) do points
        lines = Line{2, Float32}[]
        for i = 2:2:length(points)
            push!(lines, Line(points[i-1], points[i]))
        end

        intersections = Sweeping.findintersections(lines)

        hasintersection[] = !isempty(intersections)

        points = Point2f[]
        for intersection in intersections
            push!(points, intersection.p)
        end
        intersectionpoints[] = points
    end

    scatter!(
        ax,
        intersectionpoints,
        color=:red,
    )

    hasintersectiontext = @lift($hasintersection ? "Some segments are intersecting" : "No intersections found")
    Label(infogrid[1, 1:3], hasintersectiontext)

    # controls

    function pushpoint!(p)
        points[] = push!(points[], p)
    end

    function poppoint!()
        length(points[]) > 0 && pop!(points[])
        points[] = points[]
    end

    function clearpoints!()
        points[] = empty(points[])
    end

    mouseevents = addmouseevents!(ax.scene)
    onmouseleftdown(mouseevents) do event
        dpos = event.data
        pushpoint!(dpos)
    end

    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press
            if event.key == Keyboard.r
                clearpoints!()
            elseif event.key == Keyboard.a
                autolimits!(ax)
            elseif event.key == Keyboard.p
                poppoint!()
            end
        end
    end

    resetbtn = controlsgrid[1, 1] = Button(fig, label="Reset (R)")
    on(resetbtn.clicks) do n
        clearpoints!()
    end

    autoscalebtn = controlsgrid[1, 2] = Button(fig, label="Autoscale (A)")
    on(autoscalebtn.clicks) do n
        autolimits!(ax)
    end

    popbtn = controlsgrid[1, 3] = Button(fig, label="Remove last (P)")
    on(popbtn.clicks) do n
        poppoint!()
    end

    # segment generation

    Label(controlsgrid[2, 1:3], "Random segment generation")

    Label(controlsgrid[3, 1], "X min")
    xlowtb = Textbox(controlsgrid[4, 1],
        placeholder="X min",
        validator=Float32,
    )

    Label(controlsgrid[3, 2], "X max")
    xhightb = Textbox(controlsgrid[4, 2],
        placeholder="X max",
        validator=Float32,
    )

    Label(controlsgrid[5, 1], "Y min")
    ylowtb = Textbox(controlsgrid[6, 1],
        placeholder="Y min",
        validator=Float32,
    )

    Label(controlsgrid[5, 2], "Y max")
    yhightb = Textbox(controlsgrid[6, 2],
        placeholder="Y max",
        validator=Float32,
    )

    Label(controlsgrid[3, 3], "Num segments")
    numsegstb = Textbox(controlsgrid[4, 3],
        placeholder="Num segments",
        validator=Int,
    )

    generatebtn = Button(controlsgrid[5:6, 3], label="Generate")
    on(generatebtn.clicks) do n
        xlow = tryparse(Float32, xlowtb.displayed_string[])
        xhigh = tryparse(Float32, xhightb.displayed_string[])
        ylow = tryparse(Float32, ylowtb.displayed_string[])
        yhigh = tryparse(Float32, yhightb.displayed_string[])
        numsegs = tryparse(Int, numsegstb.displayed_string[])
        if isnothing(xlow) || isnothing(xhigh) || isnothing(ylow) || isnothing(yhigh) || isnothing(numsegs)
            return
        end

        xs = Float32[]
        while length(xs) != numsegs * 2
            push!(xs, unique(rand(Uniform(xlow, xhigh), numsegs * 2 - length(xs)))...)
        end
        ys = rand(Uniform(ylow, yhigh), numsegs * 2)

        for (x, y) in zip(xs, ys)
            pushpoint!(Point2f(x, y))
        end
    end

    # segment saving to file

    Label(controlsgrid[7, 1:3], "Save/load segments")

    Label(controlsgrid[8, 1], "Filename")
    filenametb = Textbox(controlsgrid[9, 1],
        placeholder="Filename",
    )
    
    savebtn = Button(controlsgrid[8, 2], label="Save")
    on(savebtn.clicks) do n
        savesegments(points[], filenametb.displayed_string[])
    end
    
    loadbtn = Button(controlsgrid[9, 2], label="Load")
    on(loadbtn.clicks) do n
        newpoints = loadsegments(filenametb.displayed_string[])
        if !isnothing(newpoints)
            points[] = newpoints
        end
    end

    display(fig)

    nothing
end

end
