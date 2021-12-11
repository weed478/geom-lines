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

    display(fig)

    nothing
end

end
