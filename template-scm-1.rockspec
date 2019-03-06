package = "template"
version = "scm-1"
source = {
    url = "git://github.com/tarantool/template.git"
}
description = {
    summary = "Templating Engine (HTML) for Tarantool",
    detailed = "template is a compiling (HTML) templating engine for Tarantool",
    homepage = "https://github.com/tarantool/template",
    license = "BSD",
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["template"]                = "lib/template.lua",
        ["template.html"]           = "lib/template/html.lua",
        ["template.microbenchmark"] = "lib/template/microbenchmark.lua"
    }
}
