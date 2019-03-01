package = "lua-resty-template"
version = "dev-1"
source = {
    url = "git://github.com/tarantool/lua-resty-template.git"
}
description = {
    summary = "Templating Engine (HTML) for Tarantool",
    detailed = "lua-resty-template is a compiling (HTML) templating engine for Tarantool",
    homepage = "https://github.com/tarantool/lua-resty-template",
    license = "BSD",
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["resty.template"]                = "lib/resty/template.lua",
        ["resty.template.html"]           = "lib/resty/template/html.lua",
        ["resty.template.microbenchmark"] = "lib/resty/template/microbenchmark.lua"
    }
}
