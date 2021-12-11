module gui

using GLMakie
using GeometryBasics

function run()
    fig = Figure()
    fig[2, 1] = controlsgrid = GridLayout(tellwidth=false)
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
        validator=Float64,
    )

    xhightb = Textbox(controlsgrid[3, 2],
        placeholder="X max",
        validator=Float64,
    )

    ylowtb = Textbox(controlsgrid[4, 1],
        placeholder="X min",
        validator=Float64,
    )

    yhightb = Textbox(controlsgrid[4, 2],
        placeholder="X max",
        validator=Float64,
    )

    generatebtn = Button(controlsgrid[3:4, 3], label="Generate")

    display(fig)

    nothing
end

end
