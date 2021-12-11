module gui

using GLMakie
using GeometryBasics
using Distributions: Uniform

function run()
    fig = Figure()
    fig[1, 2] = controlsgrid = GridLayout(tellwidth=false, tellheight=false)
    ax = Axis(fig[1, 1])
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

    xlowtb = Textbox(controlsgrid[3, 1],
        placeholder="X min",
        validator=Float32,
    )

    xhightb = Textbox(controlsgrid[3, 2],
        placeholder="X max",
        validator=Float32,
    )

    ylowtb = Textbox(controlsgrid[4, 1],
        placeholder="Y min",
        validator=Float32,
    )

    yhightb = Textbox(controlsgrid[4, 2],
        placeholder="Y max",
        validator=Float32,
    )

    numsegstb = Textbox(controlsgrid[3, 3],
        placeholder="Number of segments",
        validator=Int,
    )

    generatebtn = Button(controlsgrid[4, 3], label="Generate")
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

    Label(controlsgrid[5, 1:3], "Save/load segments")
    filenametb = Textbox(controlsgrid[6, 1],
        placeholder="Filename",
    )
    savebtn = Button(controlsgrid[6, 2], label="Save")
    loadbtn = Button(controlsgrid[6, 3], label="Load")

    display(fig)

    nothing
end

end
