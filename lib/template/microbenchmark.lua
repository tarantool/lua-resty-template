local template = require('template')

local function run(iterations)
    iterations = iterations or 1000
    local gc = collectgarbage
    local total = 0
    local parse = template.parse
    local compile = template.compile

    local view = [[
    <ul>
    {% for _, v in ipairs(context) do %}
        <li>{{v}}</li>
    {% end %}
    </ul>]]

    print(string.format("Running %d iterations in each test", iterations))

    gc()
    gc()

    local x = os.clock()
    for _ = 1, iterations do
        parse(view, true)
    end
    local z = os.clock() - x
    print(string.format("    Parsing Time: %.6f", z))
    total = total + z

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        compile(view, nil, true)
        template.cache = {}
    end
    z = os.clock() - x
    print(string.format("Compilation Time: %.6f (template)", z))
    total = total + z

    compile(view, nil, true)

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        compile(view, 1, true)
    end
    z = os.clock() - x
    print(string.format("Compilation Time: %.6f (template, cached)", z))
    total = total + z

    local context = { "Emma", "James", "Nicholas", "Mary" }

    template.cache = {}

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        compile(view, 1, true)(context)
        template.cache = {}
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (same template)", z))
    total = total + z

    template.cache = {}
    compile(view, 1, true)

    gc()
    gc()

    x = os.clock()
    for _ = 1, iterations do
        compile(view, 1, true)(context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (same template, cached)", z))
    total = total + z

    template.cache = {}

    local views = table.new(iterations, 0)
    for i = 1, iterations do
        views[i] = "<h1>Iteration " .. i .. "</h1>\n" .. view
    end

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        compile(views[i], i, true)(context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template)", z))
    total = total + z

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        compile(views[i], i, true)(context)
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, cached)", z))
    total = total + z

    local contexts = table.new(iterations, 0)

    for i = 1, iterations do
        contexts[i] = { "Emma", "James", "Nicholas", "Mary" }
    end

    template.cache = {}

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        compile(views[i], i, true)(contexts[i])
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, different context)", z))
    total = total + z

    gc()
    gc()

    x = os.clock()
    for i = 1, iterations do
        compile(views[i], i, true)(contexts[i])
    end
    z = os.clock() - x
    print(string.format("  Execution Time: %.6f (different template, different context, cached)", z))
    total = total + z
    print(string.format("      Total Time: %.6f", total))
end

return {
    run = run
}
